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

let test_create () =
  let registry = Session_registry.create () in
  let result =
    Session_registry.start ~id_gen:(make_id_gen ()) ~registry
      ~harness_session_id:"hs-1" ~harness_nonce:"n-1" ()
  in
  match result with
  | Ok entry ->
      Alcotest.(check string)
        "session id" "rs-1" entry.Session_registry.session_id;
      Alcotest.(check string) "mode" "ui" entry.Session_registry.mode;
      Alcotest.(check string)
        "ui nonce" "ui-nonce-2" entry.Session_registry.ui_nonce
  | Error _ -> Alcotest.fail "start should succeed"

let test_find () =
  let registry = Session_registry.create () in
  let _ =
    Session_registry.start ~id_gen:(make_id_gen ()) ~registry
      ~harness_session_id:"hs-1" ~harness_nonce:"n-1" ()
  in
  match Session_registry.find registry "rs-1" with
  | Some entry ->
      Alcotest.(check string)
        "found session" "rs-1" entry.Session_registry.session_id
  | None -> Alcotest.fail "should find session"

let test_find_by_harness () =
  let registry = Session_registry.create () in
  let _ =
    Session_registry.start ~id_gen:(make_id_gen ()) ~registry
      ~harness_session_id:"hs-1" ~harness_nonce:"n-1" ()
  in
  (match Session_registry.find_by_harness registry "hs-1" with
  | Some _ -> ()
  | None -> Alcotest.fail "should find by harness id");

  Alcotest.(check bool)
    "unknown harness" true
    (Session_registry.find_by_harness registry "nope" = None)

let test_duplicate () =
  let registry = Session_registry.create () in
  let id_gen = make_id_gen () in
  let _ =
    Session_registry.start ~id_gen ~registry ~harness_session_id:"hs-1"
      ~harness_nonce:"n-1" ()
  in
  match
    Session_registry.start ~id_gen ~registry ~harness_session_id:"hs-1"
      ~harness_nonce:"n-2" ()
  with
  | Error `Duplicate -> ()
  | _ -> Alcotest.fail "should reject duplicate harness session"

let test_attach_detach_ui () =
  let registry = Session_registry.create () in
  let _ =
    Session_registry.start ~id_gen:(make_id_gen ()) ~registry
      ~harness_session_id:"hs-1" ~harness_nonce:"n-1" ()
  in
  (match
     Session_registry.attach_ui registry "rs-1" ~conn_id:"c-1" ~revision:0
   with
  | Ok () -> ()
  | Error _ -> Alcotest.fail "attach should succeed");
  Alcotest.(check int)
    "one ui conn" 1
    (Stdlib.List.length (Session_registry.ui_connections registry "rs-1"));
  (match Session_registry.detach_ui registry "rs-1" ~conn_id:"c-1" with
  | Ok () -> ()
  | Error _ -> Alcotest.fail "detach should succeed");
  Alcotest.(check int)
    "zero ui conns" 0
    (Stdlib.List.length (Session_registry.ui_connections registry "rs-1"))

let test_multiple_ui_connections () =
  let registry = Session_registry.create () in
  let _ =
    Session_registry.start ~id_gen:(make_id_gen ()) ~registry
      ~harness_session_id:"hs-1" ~harness_nonce:"n-1" ()
  in
  let _ =
    Session_registry.attach_ui registry "rs-1" ~conn_id:"c-1" ~revision:0
  in
  let _ =
    Session_registry.attach_ui registry "rs-1" ~conn_id:"c-2" ~revision:0
  in
  let _ =
    Session_registry.attach_ui registry "rs-1" ~conn_id:"c-3" ~revision:0
  in
  Alcotest.(check int)
    "three ui conns" 3
    (Stdlib.List.length (Session_registry.ui_connections registry "rs-1"));
  let _ = Session_registry.detach_ui registry "rs-1" ~conn_id:"c-2" in
  Alcotest.(check int)
    "two ui conns after detach" 2
    (Stdlib.List.length (Session_registry.ui_connections registry "rs-1"))

let test_attach_detach_harness () =
  let registry = Session_registry.create () in
  let _ =
    Session_registry.start ~id_gen:(make_id_gen ()) ~registry
      ~harness_session_id:"hs-1" ~harness_nonce:"n-1" ()
  in
  (match Session_registry.attach_harness registry "rs-1" ~conn_id:"h-1" with
  | Ok () -> ()
  | Error _ -> Alcotest.fail "attach should succeed");
  Alcotest.(check bool)
    "harness attached" true
    (Session_registry.harness_connection registry "rs-1" <> None);
  let _ = Session_registry.detach_harness registry "rs-1" in
  Alcotest.(check bool)
    "harness detached" true
    (Session_registry.harness_connection registry "rs-1" = None)

let test_reconnect_ui () =
  let registry = Session_registry.create () in
  let _ =
    Session_registry.start ~id_gen:(make_id_gen ()) ~registry
      ~harness_session_id:"hs-1" ~harness_nonce:"n-1" ()
  in
  let _ =
    Session_registry.attach_ui registry "rs-1" ~conn_id:"c-1" ~revision:0
  in
  let _ =
    Session_registry.reconnect_ui registry "rs-1" ~conn_id:"c-1" ~revision:5
  in
  let conns = Session_registry.ui_connections registry "rs-1" in
  match
    Stdlib.List.find_opt
      (fun (c : Session_registry.ui_conn) -> c.conn_id = "c-1")
      conns
  with
  | Some c -> Alcotest.(check int) "reconnected revision" 5 c.revision
  | None -> Alcotest.fail "should find reconnected conn"

let test_attach_not_found () =
  let registry = Session_registry.create () in
  match
    Session_registry.attach_ui registry "nope" ~conn_id:"c-1" ~revision:0
  with
  | Error `NotFound -> ()
  | _ -> Alcotest.fail "should reject unknown session"

let test_concurrent_sessions_isolated () =
  let registry = Session_registry.create () in
  let id_gen = make_id_gen () in
  let _ =
    Session_registry.start ~id_gen ~registry ~harness_session_id:"hs-1"
      ~harness_nonce:"n-1" ()
  in
  let _ =
    Session_registry.start ~id_gen ~registry ~harness_session_id:"hs-2"
      ~harness_nonce:"n-2" ()
  in
  let _ =
    Session_registry.attach_ui registry "rs-1" ~conn_id:"c-a" ~revision:0
  in
  let _ =
    Session_registry.attach_ui registry "rs-3" ~conn_id:"c-b" ~revision:0
  in
  let _ = Session_registry.attach_harness registry "rs-1" ~conn_id:"h-a" in
  let _ = Session_registry.attach_harness registry "rs-3" ~conn_id:"h-b" in
  Alcotest.(check int)
    "session 1 has 1 ui" 1
    (Stdlib.List.length (Session_registry.ui_connections registry "rs-1"));
  Alcotest.(check int)
    "session 2 has 1 ui" 1
    (Stdlib.List.length (Session_registry.ui_connections registry "rs-3"));
  Alcotest.(check bool)
    "session 1 harness" true
    (Session_registry.harness_connection registry "rs-1" <> None);
  Alcotest.(check bool)
    "session 2 harness" true
    (Session_registry.harness_connection registry "rs-3" <> None);
  let _ = Session_registry.detach_ui registry "rs-1" ~conn_id:"c-a" in
  Alcotest.(check int)
    "session 1 ui detached" 0
    (Stdlib.List.length (Session_registry.ui_connections registry "rs-1"));
  Alcotest.(check int)
    "session 2 ui untouched" 1
    (Stdlib.List.length (Session_registry.ui_connections registry "rs-3"))

let () =
  Alcotest.run "ribosome-session-registry"
    [
      ( "registry",
        [
          Alcotest.test_case "create" `Quick test_create;
          Alcotest.test_case "find" `Quick test_find;
          Alcotest.test_case "find by harness" `Quick test_find_by_harness;
          Alcotest.test_case "duplicate" `Quick test_duplicate;
        ] );
      ( "connections",
        [
          Alcotest.test_case "attach detach ui" `Quick test_attach_detach_ui;
          Alcotest.test_case "multiple ui connections" `Quick
            test_multiple_ui_connections;
          Alcotest.test_case "attach detach harness" `Quick
            test_attach_detach_harness;
          Alcotest.test_case "reconnect ui" `Quick test_reconnect_ui;
          Alcotest.test_case "attach not found" `Quick test_attach_not_found;
        ] );
      ( "isolation",
        [
          Alcotest.test_case "concurrent sessions isolated" `Quick
            test_concurrent_sessions_isolated;
        ] );
    ]
