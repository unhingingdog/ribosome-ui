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

let template_json =
  {json|{"kind":"submittable","id":"form1","value":[{"kind":"input","id":"inp1","value":"hi"}],"button":{"id":"btn1","label":"Go","action":"Submit"}}|json}

let updates = ref []
let session_states = ref []
let rejections = ref []
let user_turns = ref []

let reset () =
  updates := [];
  session_states := [];
  rejections := [];
  user_turns := []

let make_broadcast () =
  {
    Ui_runtime.broadcast_template_update =
      (fun ~session_id ~revision ~tree ->
        updates := (session_id, revision, tree) :: !updates);
    broadcast_session_state =
      (fun ~session_id ~mode ~revision ~tree ~generation_id ->
        session_states :=
          (session_id, mode, revision, tree, generation_id) :: !session_states);
    broadcast_event_rejection =
      (fun ~session_id ~event_id ~reason ->
        rejections := (session_id, event_id, reason) :: !rejections);
    send_user_turn =
      (fun ~session_id ~tree ~event ->
        user_turns := (session_id, tree, event) :: !user_turns);
  }

let make_runtime_with_tree () =
  let registry = Session_registry.create () in
  let _ =
    Session_registry.start ~id_gen:(make_id_gen ()) ~registry
      ~harness_session_id:"hs-1" ~harness_nonce:"hn-1" ()
  in
  let broadcast = make_broadcast () in
  let runtime = Ui_runtime.create ~registry ~broadcast in
  Ui_runtime.register_session runtime ~session_id:"rs-1";
  (* Create a session with a tree by feeding through Ribosome.Session directly *)
  let session = Ribosome.Session.create ~id:"rs-1" ~mode:Ribosome.Mode.ui in
  let session =
    match Ribosome.Session.start_generation session ~gen_id:"gen-1" with
    | Ok s -> s
    | Error e -> failwith e
  in
  let session =
    match
      Ribosome.Session.feed_delta session ~gen_id:"gen-1" ~seq:0
        ~delta:template_json
    with
    | Ok (s, _) -> s
    | Error e -> failwith e
  in
  let session =
    match Ribosome.Session.complete_generation session ~gen_id:"gen-1" with
    | Ok s -> s
    | Error e -> failwith e
  in
  Ui_runtime.put_session runtime ~session_id:"rs-1" session;
  reset ();
  runtime

let test_attach_sends_snapshot () =
  reset ();
  let runtime = make_runtime_with_tree () in
  let msg = Ui_protocol.Attach { session_id = "rs-1"; revision = None } in
  (match Ui_runtime.handle_message runtime msg with
  | Ok () -> ()
  | Error _ -> Alcotest.fail "attach should succeed");
  Alcotest.(check int) "snapshot sent" 1 (Stdlib.List.length !session_states);
  match !session_states with
  | (_, mode, rev, tree_opt, gen_opt) :: _ ->
      Alcotest.(check string) "mode is ui" "ui" mode;
      Alcotest.(check bool) "has tree" true (tree_opt <> None);
      Alcotest.(check bool) "no active generation" true (gen_opt = None);
      Alcotest.(check int) "revision is 1" 1 rev
  | [] -> ()

let test_attach_creates_session () =
  reset ();
  let runtime = make_runtime_with_tree () in
  let msg =
    Ui_protocol.Attach { session_id = "new-session"; revision = None }
  in
  match Ui_runtime.handle_message runtime msg with
  | Ok () -> ()
  | Error e ->
      Alcotest.fail
        ("expected Ok for new session, got " ^ Ui_runtime.error_string e)

let test_change_broadcasts_update () =
  reset ();
  let runtime = make_runtime_with_tree () in
  let msg =
    Ui_protocol.ComponentEvent
      {
        session_id = "rs-1";
        revision = 1;
        event_id = "evt-1";
        target_id = "inp1";
        kind = Ui_protocol.Change;
        value = Some (`String "new value");
      }
  in
  (match Ui_runtime.handle_message runtime msg with
  | Ok () -> ()
  | Error e ->
      Alcotest.fail
        ("change should succeed: "
        ^ match e with EventError s -> s | _ -> "other"));
  Alcotest.(check int) "one update broadcast" 1 (Stdlib.List.length !updates);
  Alcotest.(check int) "no user turns" 0 (Stdlib.List.length !user_turns)

let test_submit_produces_user_turn () =
  reset ();
  let runtime = make_runtime_with_tree () in
  let msg =
    Ui_protocol.ComponentEvent
      {
        session_id = "rs-1";
        revision = 1;
        event_id = "evt-2";
        target_id = "form1";
        kind = Ui_protocol.Submit;
        value = None;
      }
  in
  (match Ui_runtime.handle_message runtime msg with
  | Ok () -> ()
  | Error e ->
      Alcotest.fail
        ("submit should succeed: "
        ^ match e with EventError s -> s | _ -> "other"));
  Alcotest.(check int)
    "exactly one user turn" 1
    (Stdlib.List.length !user_turns)

let test_click_produces_user_turn () =
  reset ();
  let runtime = make_runtime_with_tree () in
  let msg =
    Ui_protocol.ComponentEvent
      {
        session_id = "rs-1";
        revision = 1;
        event_id = "evt-3";
        target_id = "btn1";
        kind = Ui_protocol.Click;
        value = None;
      }
  in
  (match Ui_runtime.handle_message runtime msg with
  | Ok () -> ()
  | Error e ->
      Alcotest.fail
        ("click should succeed: "
        ^ match e with EventError s -> s | _ -> "other"));
  Alcotest.(check int)
    "exactly one user turn" 1
    (Stdlib.List.length !user_turns)

let test_stale_revision_rejected () =
  reset ();
  let runtime = make_runtime_with_tree () in
  let msg =
    Ui_protocol.ComponentEvent
      {
        session_id = "rs-1";
        revision = 99;
        event_id = "evt-4";
        target_id = "inp1";
        kind = Ui_protocol.Change;
        value = Some (`String "x");
      }
  in
  let _ = Ui_runtime.handle_message runtime msg in
  Alcotest.(check int) "rejection sent" 1 (Stdlib.List.length !rejections);
  match !rejections with
  | (_, _, reason) :: _ ->
      Alcotest.(check string)
        "stale revision reason" "StaleRevision"
        (match reason with
        | Ui_protocol.StaleRevision -> "StaleRevision"
        | _ -> "wrong")
  | [] -> ()

let test_duplicate_event_rejected () =
  reset ();
  let runtime = make_runtime_with_tree () in
  let msg1 =
    Ui_protocol.ComponentEvent
      {
        session_id = "rs-1";
        revision = 1;
        event_id = "evt-dup";
        target_id = "inp1";
        kind = Ui_protocol.Change;
        value = Some (`String "first");
      }
  in
  let msg2 =
    Ui_protocol.ComponentEvent
      {
        session_id = "rs-1";
        revision = 2;
        event_id = "evt-dup";
        target_id = "inp1";
        kind = Ui_protocol.Change;
        value = Some (`String "second");
      }
  in
  let _ = Ui_runtime.handle_message runtime msg1 in
  reset ();
  let _ = Ui_runtime.handle_message runtime msg2 in
  Alcotest.(check int) "rejection sent" 1 (Stdlib.List.length !rejections)

let test_event_wrong_session () =
  reset ();
  let runtime = make_runtime_with_tree () in
  let msg =
    Ui_protocol.ComponentEvent
      {
        session_id = "nope";
        revision = 1;
        event_id = "evt-5";
        target_id = "inp1";
        kind = Ui_protocol.Change;
        value = Some (`String "x");
      }
  in
  match Ui_runtime.handle_message runtime msg with
  | Error Ui_runtime.InvalidSession -> ()
  | _ -> Alcotest.fail "expected InvalidSession"

let () =
  Alcotest.run "ribosome-ui-runtime"
    [
      ( "attach",
        [
          Alcotest.test_case "attach sends snapshot" `Quick
            test_attach_sends_snapshot;
          Alcotest.test_case "attach creates session" `Quick
            test_attach_creates_session;
        ] );
      ( "events",
        [
          Alcotest.test_case "change broadcasts update" `Quick
            test_change_broadcasts_update;
          Alcotest.test_case "submit produces user turn" `Quick
            test_submit_produces_user_turn;
          Alcotest.test_case "click produces user turn" `Quick
            test_click_produces_user_turn;
        ] );
      ( "rejections",
        [
          Alcotest.test_case "stale revision rejected" `Quick
            test_stale_revision_rejected;
          Alcotest.test_case "duplicate event rejected" `Quick
            test_duplicate_event_rejected;
          Alcotest.test_case "event wrong session" `Quick
            test_event_wrong_session;
        ] );
    ]
