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
  let skill_path = Filename.concat root "ribosome/SKILL.md" in
  read_file skill_path

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
  let skills = load_skills skill_root in
  let skill_loader = function
    | "skills/ribosome/SKILL.md" -> skills
    | _ -> None
  in
  { Ribosome_server_lib.Mcp.registry; id_gen; skill_loader }

let make_runtimes config =
  let h_broadcast =
    {
      Ribosome_server_lib.Harness_runtime.broadcast_template_update =
        (fun ~session_id ~revision ~tree ->
          Debug.log "harness_broadcast"
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
          Ribosome_server_lib.Message_queue.push session_id msg);
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
          Ribosome_server_lib.Message_queue.push session_id msg);
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
          Ribosome_server_lib.Message_queue.push session_id msg);
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
          Ribosome_server_lib.Message_queue.push session_id msg);
      send_user_turn =
        (fun ~session_id ~tree:_ ~event:_ ->
          Debug.log "ui_broadcast"
            (Printf.sprintf "user_turn session=%s" session_id);
          ());
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
  Ribosome_server_lib.Websocket_transport.create ~harness ~ui

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
