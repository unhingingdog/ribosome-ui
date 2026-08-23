open Ribosome_server_lib

(* Task 7.1: protocol-only UI client tests.
   The client attaches, observes updates, submits a form, and reconnects —
   all through Ui_protocol messages against in-memory Ui_runtime. *)

let setup () =
  let _registry, runtime, inbox = Vslice_support.make_runtime_with_tree () in
  Ui_client.clear_inbox inbox;
  (runtime, inbox)

let test_attach_receives_snapshot () =
  let runtime, inbox = setup () in
  let client = Ui_client.make_client ~session_id:"rs-1" in
  Ui_client.send_attach client runtime ~reconnect:false;
  let n = Ui_client.drain_inbox client inbox in
  Alcotest.(check int) "one message received" 1 n;
  Alcotest.(check bool) "client is connected" true client.Ui_client.connected;
  Alcotest.(check int) "revision is 1" 1 client.Ui_client.revision;
  Alcotest.(check bool) "has tree" true (client.Ui_client.tree <> None);
  Alcotest.(check string) "mode is ui" "ui" client.Ui_client.mode

let test_change_updates_revision_and_tree () =
  let runtime, inbox = setup () in
  let client = Ui_client.make_client ~session_id:"rs-1" in
  Ui_client.send_attach client runtime ~reconnect:false;
  let _ = Ui_client.drain_inbox client inbox in
  let _ =
    Ui_client.send_change client runtime ~target_id:"inp1"
      ~value:(`String "new value")
  in
  let n = Ui_client.drain_inbox client inbox in
  Alcotest.(check int) "one template update" 1 n;
  Alcotest.(check int) "revision bumped to 2" 2 client.Ui_client.revision

let test_submit_produces_user_turn () =
  let runtime, inbox = setup () in
  let client = Ui_client.make_client ~session_id:"rs-1" in
  Ui_client.send_attach client runtime ~reconnect:false;
  let _ = Ui_client.drain_inbox client inbox in
  let _ = Ui_client.send_submit client runtime ~target_id:"form1" in
  let _n = Ui_client.drain_inbox client inbox in
  Alcotest.(check int)
    "one user turn captured" 1
    (Stdlib.List.length inbox.Ui_client.user_turns)

let test_click_produces_user_turn () =
  let runtime, inbox = setup () in
  let client = Ui_client.make_client ~session_id:"rs-1" in
  Ui_client.send_attach client runtime ~reconnect:false;
  let _ = Ui_client.drain_inbox client inbox in
  let _ = Ui_client.send_click client runtime ~target_id:"btn1" in
  let _n = Ui_client.drain_inbox client inbox in
  Alcotest.(check int)
    "one user turn captured" 1
    (Stdlib.List.length inbox.Ui_client.user_turns)

let test_stale_revision_rejected () =
  let runtime, inbox = setup () in
  let client = Ui_client.make_client ~session_id:"rs-1" in
  Ui_client.send_attach client runtime ~reconnect:false;
  let _ = Ui_client.drain_inbox client inbox in
  (* Manually set a stale revision *)
  client.Ui_client.revision <- 0;
  let result = Ui_client.send_submit client runtime ~target_id:"form1" in
  let _ = Ui_client.drain_inbox client inbox in
  (match result with
  | Error (Ui_runtime.EventError _) -> ()
  | _ -> Alcotest.fail "expected stale revision rejection");
  Alcotest.(check int)
    "rejection captured" 1
    (Stdlib.List.length inbox.Ui_client.rejections)

let test_reconnect_from_known_revision () =
  let runtime, inbox = setup () in
  let client = Ui_client.make_client ~session_id:"rs-1" in
  Ui_client.send_attach client runtime ~reconnect:false;
  let _ = Ui_client.drain_inbox client inbox in
  (* Disconnect *)
  Ui_client.send_disconnect client runtime;
  Alcotest.(check bool) "disconnected" false client.Ui_client.connected;
  (* Reconnect from known revision *)
  Ui_client.send_attach client runtime ~reconnect:true;
  let n = Ui_client.drain_inbox client inbox in
  Alcotest.(check int) "snapshot on reconnect" 1 n;
  Alcotest.(check bool) "connected again" true client.Ui_client.connected;
  Alcotest.(check int) "revision preserved" 1 client.Ui_client.revision

let test_event_ids_are_unique () =
  let runtime, inbox = setup () in
  let client = Ui_client.make_client ~session_id:"rs-1" in
  Ui_client.send_attach client runtime ~reconnect:false;
  let _ = Ui_client.drain_inbox client inbox in
  let _ =
    Ui_client.send_change client runtime ~target_id:"inp1" ~value:(`String "a")
  in
  let _ = Ui_client.drain_inbox client inbox in
  let _ =
    Ui_client.send_change client runtime ~target_id:"inp1" ~value:(`String "b")
  in
  let _ = Ui_client.drain_inbox client inbox in
  let _ =
    Ui_client.send_change client runtime ~target_id:"inp1" ~value:(`String "c")
  in
  let _ = Ui_client.drain_inbox client inbox in
  Alcotest.(check int) "revision at 4" 4 client.Ui_client.revision

let () =
  Alcotest.run "ribosome-ui-client"
    [
      ( "client",
        [
          Alcotest.test_case "attach receives snapshot" `Quick
            test_attach_receives_snapshot;
          Alcotest.test_case "change updates revision" `Quick
            test_change_updates_revision_and_tree;
          Alcotest.test_case "submit produces user turn" `Quick
            test_submit_produces_user_turn;
          Alcotest.test_case "click produces user turn" `Quick
            test_click_produces_user_turn;
          Alcotest.test_case "stale revision rejected" `Quick
            test_stale_revision_rejected;
          Alcotest.test_case "reconnect from known revision" `Quick
            test_reconnect_from_known_revision;
          Alcotest.test_case "event ids are unique" `Quick
            test_event_ids_are_unique;
        ] );
    ]
