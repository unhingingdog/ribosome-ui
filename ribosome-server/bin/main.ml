(* ribosome-server executable entry point.

   Composes MCP stdio processing and Dream WebSocket routes in one Lwt
   runtime. Cmdliner options control interface, port, public UI URL, and
   skill root. *)

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
        (fun ~session_id ~revision ~tree:_ ->
          let () =
            Printf.eprintf "[harness] update session=%s rev=%d\n" session_id
              revision
          in
          flush stderr);
    }
  in
  let u_broadcast =
    {
      Ribosome_server_lib.Ui_runtime.broadcast_template_update =
        (fun ~session_id ~revision ~tree:_ ->
          let () =
            Printf.eprintf "[ui] update session=%s rev=%d\n" session_id revision
          in
          flush stderr);
      broadcast_session_state =
        (fun ~session_id ~mode ~revision ~tree:_ ~generation_id:_ ->
          let () =
            Printf.eprintf "[ui] snapshot session=%s mode=%s rev=%d\n"
              session_id mode revision
          in
          flush stderr);
      broadcast_event_rejection =
        (fun ~session_id ~event_id ~reason:_ ->
          let () =
            Printf.eprintf "[ui] reject session=%s event=%s\n" session_id
              event_id
          in
          flush stderr);
      send_user_turn =
        (fun ~session_id ~tree:_ ~event:_ ->
          let () = Printf.eprintf "[ui] user_turn session=%s\n" session_id in
          flush stderr);
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
