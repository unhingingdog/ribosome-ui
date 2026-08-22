open Ribosome_server_lib

let make_id_gen () =
  let n = ref 0 in
  {
    Session_registry.gen_session_id =
      (fun () ->
        incr n;
        "rs-" ^ string_of_int !n);
    gen_ui_nonce =
      (fun () ->
        incr n;
        "ui-nonce-" ^ string_of_int !n);
  }

let make_registry () =
  let registry = Session_registry.create () in
  let _ =
    Session_registry.start ~id_gen:(make_id_gen ()) ~registry
      ~harness_session_id:"hs-1" ~harness_nonce:"hn-1" ()
  in
  registry

let test_harness_handler_max_message_size () =
  Alcotest.(check int) "1 MiB" (1 lsl 20) Harness_handler.max_message_size

let test_ui_handler_max_message_size () =
  Alcotest.(check int) "1 MiB" (1 lsl 20) Ui_handler.max_message_size

let test_websocket_transport_loopback () =
  Alcotest.(check string) "loopback" "127.0.0.1" Websocket_transport.loopback

let test_websocket_transport_max_message_size () =
  Alcotest.(check int) "1 MiB" (1 lsl 20) Websocket_transport.max_message_size

let test_websocket_transport_create () =
  let registry = make_registry () in
  let h_broadcast =
    {
      Harness_runtime.broadcast_template_update =
        (fun ~session_id:_ ~revision:_ ~tree:_ -> ());
    }
  in
  let u_broadcast =
    {
      Ui_runtime.broadcast_template_update =
        (fun ~session_id:_ ~revision:_ ~tree:_ -> ());
      broadcast_session_state =
        (fun ~session_id:_ ~mode:_ ~revision:_ ~tree:_ ~generation_id:_ -> ());
      broadcast_event_rejection =
        (fun ~session_id:_ ~event_id:_ ~reason:_ -> ());
      send_user_turn = (fun ~session_id:_ ~tree:_ ~event:_ -> ());
    }
  in
  let harness = Harness_runtime.create ~registry ~broadcast:h_broadcast in
  let ui = Ui_runtime.create ~registry ~broadcast:u_broadcast in
  let _runtime = Websocket_transport.create ~harness ~ui in
  Alcotest.(check bool) "runtime created" true true

let () =
  Lwt_main.run
    (Alcotest_lwt.run "ribosome-websocket-transport"
       [
         ( "config",
           [
             Alcotest_lwt.test_case "harness max message size" `Quick
               (fun _ () ->
                 Lwt.return (test_harness_handler_max_message_size ()));
             Alcotest_lwt.test_case "ui max message size" `Quick (fun _ () ->
                 Lwt.return (test_ui_handler_max_message_size ()));
             Alcotest_lwt.test_case "loopback" `Quick (fun _ () ->
                 Lwt.return (test_websocket_transport_loopback ()));
             Alcotest_lwt.test_case "transport max message size" `Quick
               (fun _ () ->
                 Lwt.return (test_websocket_transport_max_message_size ()));
           ] );
         ( "runtime",
           [
             Alcotest_lwt.test_case "create" `Quick (fun _ () ->
                 Lwt.return (test_websocket_transport_create ()));
           ] );
       ])
