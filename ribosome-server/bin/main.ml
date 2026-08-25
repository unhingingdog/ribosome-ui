(* ribosome-server executable entry point.

   Composes MCP stdio processing and Dream WebSocket routes in one Lwt
   runtime. Cmdliner options control interface, port, public UI URL, and
   skill root. *)

module Debug = Ribosome_server_lib.Debug

let read_file path =
  try
    let ic = open_in path in
    let len = in_channel_length ic in
    let s = really_input_string ic len in
    close_in ic;
    Some s
  with _ -> None

let load_skills root =
  let skill_names = [ "ribosome"; "show-me"; "isometric-diagram"; "ribosome-conversation"; "pr-quizzer" ] in
  let table = Hashtbl.create 8 in
  Stdlib.List.iter (fun name ->
    let path = Filename.concat (Filename.concat root name) "SKILL.md" in
    match read_file path with
    | Some content -> Hashtbl.add table name content
    | None -> ()
  ) skill_names;
  table

let make_config ~skill_root =
  let registry = Ribosome_server_lib.Session_registry.create () in
  let id_gen =
    let n = ref 0 in
    {
      Ribosome_server_lib.Session_registry.gen_session_id =
        (fun () ->
          incr n;
          "rs-" ^ string_of_int !n);
      gen_ui_nonce =
        (fun () ->
          incr n;
          "ui-nonce-" ^ string_of_int !n);
    }
  in
  let skills_table = load_skills skill_root in
  let skill_loader path =
    let name = Filename.basename (Filename.dirname path) in
    Hashtbl.find_opt skills_table name
  in
  { Ribosome_server_lib.Mcp.registry; id_gen; skill_loader }

let make_runtimes config =
  let ui_conns = Ribosome_server_lib.Connection_table.create () in
  let harness_conns = Ribosome_server_lib.Connection_table.create () in
  (* Forward refs for cross-runtime session sync *)
  let harness_ref = ref None in
  let ui_ref = ref None in
  let sync_harness_to_ui ~session_id =
    match (!harness_ref, !ui_ref) with
    | (Some h, Some u) ->
        (match Ribosome_server_lib.Harness_runtime.get_session h ~session_id with
         | Some session ->
             Ribosome_server_lib.Ui_runtime.put_session u ~session_id session
         | None -> ())
    | _ -> ()
  in
  let sync_ui_to_harness ~session_id =
    match (!ui_ref, !harness_ref) with
    | (Some u, Some h) ->
        (match Ribosome_server_lib.Ui_runtime.get_session u ~session_id with
         | Some ui_session ->
             (match Ribosome_server_lib.Harness_runtime.get_session h ~session_id with
              | Some harness_session ->
                  let synced =
                    { (ui_session : Ribosome.Session.t) with
                      generation = harness_session.Ribosome.Session.generation;
                      incremental = harness_session.Ribosome.Session.incremental;
                    }
                  in
                  Ribosome_server_lib.Harness_runtime.put_session h ~session_id synced
              | None ->
                  Ribosome_server_lib.Harness_runtime.put_session h ~session_id ui_session)
         | None -> ())
    | _ -> ()
  in
  let h_broadcast =
    {
      Ribosome_server_lib.Harness_runtime.broadcast_template_update =
        (fun ~session_id ~revision ~tree ->
          Debug.log "harness_broadcast"
            (Printf.sprintf "template_update session=%s rev=%d" session_id
               revision);
          (* Sync session from harness → UI so revisions stay aligned *)
          sync_harness_to_ui ~session_id;
          let msg =
            Yojson.Safe.to_string
              (`Assoc
                 [
                   ("kind", `String "template_update");
                   ("session_id", `String session_id);
                   ("revision", `Int revision);
                   ("tree", `String tree);
                 ])
          in
          Ribosome_server_lib.Connection_table.send ui_conns ~session_id msg);
    }
  in
  let u_broadcast =
    {
      Ribosome_server_lib.Ui_runtime.broadcast_template_update =
        (fun ~session_id ~revision ~tree ->
          Debug.log "ui_broadcast"
            (Printf.sprintf "template_update session=%s rev=%d" session_id
               revision);
          let msg =
            Yojson.Safe.to_string
              (`Assoc
                 [
                   ("kind", `String "template_update");
                   ("session_id", `String session_id);
                   ("revision", `Int revision);
                   ("tree", `String tree);
                 ])
          in
          Ribosome_server_lib.Connection_table.send ui_conns ~session_id msg);
      broadcast_session_state =
        (fun ~session_id ~mode ~revision ~tree ~generation_id ->
          Debug.log "ui_broadcast"
            (Printf.sprintf "session_state session=%s mode=%s rev=%d" session_id
               mode revision);
          let fields =
            [
              ("kind", `String "session_state");
              ("session_id", `String session_id);
              ("mode", `String mode);
              ("revision", `Int revision);
            ]
          in
          let fields =
            match tree with
            | Some t -> fields @ [ ("tree", `String t) ]
            | None -> fields
          in
          let fields =
            match generation_id with
            | Some g -> fields @ [ ("generation_id", `String g) ]
            | None -> fields
          in
          let msg = Yojson.Safe.to_string (`Assoc fields) in
          Ribosome_server_lib.Connection_table.send ui_conns ~session_id msg);
      broadcast_event_rejection =
        (fun ~session_id ~event_id ~reason ->
          Debug.log "ui_broadcast"
            (Printf.sprintf "event_rejection session=%s event=%s" session_id
               event_id);
          let msg =
            Yojson.Safe.to_string
              (`Assoc
                 [
                   ("kind", `String "event_rejection");
                   ("session_id", `String session_id);
                   ("event_id", `String event_id);
                   ( "reason",
                     `String
                       (Ribosome_server_lib.Ui_protocol
                        .rejection_reason_to_string reason) );
                 ])
          in
          Ribosome_server_lib.Connection_table.send ui_conns ~session_id msg);
      send_user_turn =
        (fun ~session_id ~tree ~event ->
          Debug.log "ui_broadcast"
            (Printf.sprintf "user_turn session=%s" session_id);
          (* Sync session from UI → harness so revisions stay aligned *)
          sync_ui_to_harness ~session_id;
          let msg =
            Yojson.Safe.to_string
              (`Assoc
                 [
                   ("kind", `String "user_turn");
                   ("session_id", `String session_id);
                   ("tree", `String tree);
                   ("event", `String event);
                 ])
          in
          Ribosome_server_lib.Connection_table.send harness_conns ~session_id
            msg);
    }
  in
  let harness =
    Ribosome_server_lib.Harness_runtime.create
      ~registry:config.Ribosome_server_lib.Mcp.registry ~broadcast:h_broadcast
  in
  let ui =
    Ribosome_server_lib.Ui_runtime.create
      ~registry:config.Ribosome_server_lib.Mcp.registry ~broadcast:u_broadcast
  in
  harness_ref := Some harness;
  ui_ref := Some ui;
  Ribosome_server_lib.Websocket_transport.create ~harness ~ui ~ui_conns
    ~harness_conns

let () =
  let open Cmdliner in
  let interface_ =
    Arg.(
      value & opt string "127.0.0.1"
      & info [ "interface" ] ~doc:"Network interface")
  in
  let port = Arg.(value & opt int 8787 & info [ "port" ] ~doc:"HTTP port") in
  let public_ui_url =
    Arg.(
      value
      & opt string "http://127.0.0.1:8787"
      & info [ "public-ui-url" ] ~doc:"Public UI URL")
  in
  let skill_root =
    Arg.(
      value & opt string "skills"
      & info [ "skill-root" ] ~doc:"Skill files root directory")
  in
  let stdio =
    Arg.(value & flag & info [ "stdio" ] ~doc:"Enable MCP stdio processing")
  in
  let compose interface_ port _public_ui_url skill_root stdio =
    Debug.log "main"
      (Printf.sprintf "starting interface=%s port=%d stdio=%b" interface_ port
         stdio);
    let config = make_config ~skill_root in
    let ws_runtime = make_runtimes config in
    let combined =
      Dream.router
        (Ribosome_server_lib.Websocket_transport.routes ws_runtime
        @ [
            Dream.get "/health" (fun _ ->
                Dream.json
                  (Printf.sprintf "{\"status\":\"ok\",\"version\":\"%s\"}"
                     Ribosome_server_lib.Server.core_version));
            Dream.get "/templates" (fun _ ->
                if Ribosome_server_lib.Debug.enabled then
                  Dream.json Ribosome_server_lib.Home_template.templates_json
                else
                  Dream.respond ~status:`Not_Found
                    (Yojson.Safe.to_string (`String "not found")));
            Dream.get "/skills" (fun _ ->
                let skills_table = load_skills skill_root in
                let entries =
                  Hashtbl.fold (fun name content acc ->
                    `Assoc [
                      ("name", `String name);
                      ("content", `String content);
                    ] :: acc
                  ) skills_table []
                in
                Dream.json (Yojson.Safe.to_string (`List (Stdlib.List.rev entries))));
          ])
    in
    Lwt_main.run
      (let open Lwt.Syntax in
       if stdio then
         let* _ =
           Lwt.both
             (Ribosome_server_lib.Mcp_stdio.process_stdin ~config)
             (Dream.serve ~interface:interface_ ~port combined)
         in
         Lwt.return_unit
       else begin
         Dream.run ~interface:interface_ ~port combined;
         Lwt.return_unit
       end)
  in
  let term =
    Term.(
      const compose $ interface_ $ port $ public_ui_url $ skill_root $ stdio)
  in
  let info = Cmd.info "ribosome-server" ~version:"0.0.0" in
  exit (Cmd.eval (Cmd.v info term))
