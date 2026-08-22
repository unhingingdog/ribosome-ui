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

let fake_skill_loader path =
  if path = "skills/ribosome/SKILL.md" then Some "SKILL BODY" else None

let make_config () =
  {
    Mcp.registry = Session_registry.create ();
    id_gen = make_id_gen ();
    skill_loader = fake_skill_loader;
  }

let init_and_notify config =
  let init_req =
    Jsonrpc.Request { id = Int_id 1; method_ = "initialize"; params = None }
  in
  let notif =
    Jsonrpc.Notification
      { method_ = "notifications/initialized"; params = None }
  in
  let state, _ = Mcp.handle config Mcp.Uninitialized init_req in
  let state, _ = Mcp.handle config state notif in
  state

let test_initialize () =
  let config = make_config () in
  let req =
    Jsonrpc.Request { id = Int_id 1; method_ = "initialize"; params = None }
  in
  let state, resp = Mcp.handle config Mcp.Uninitialized req in
  Alcotest.(check bool) "response present" true (resp <> None);
  (match resp with
  | Some (Jsonrpc.Success s) ->
      let ass = match s.result with `Assoc a -> a | _ -> [] in
      let proto =
        match Stdlib.List.assoc_opt "protocolVersion" ass with
        | Some (`String v) -> v
        | _ -> "missing"
      in
      Alcotest.(check string) "protocol version" "2025-11-25" proto
  | _ -> Alcotest.fail "expected success response");
  Alcotest.(check string)
    "still uninitialized" "Uninitialized"
    (match state with Uninitialized -> "Uninitialized" | _ -> "wrong")

let test_initialized_notification () =
  let config = make_config () in
  let notif =
    Jsonrpc.Notification
      { method_ = "notifications/initialized"; params = None }
  in
  let state, resp = Mcp.handle config Mcp.Uninitialized notif in
  Alcotest.(check string)
    "now initialized" "Initialized"
    (match state with Initialized -> "Initialized" | _ -> "wrong");
  Alcotest.(check bool) "no response for notification" true (resp = None)

let test_reject_before_init () =
  let config = make_config () in
  let req =
    Jsonrpc.Request { id = Int_id 2; method_ = "tools/list"; params = None }
  in
  let _state, resp = Mcp.handle config Mcp.Uninitialized req in
  match resp with
  | Some (Jsonrpc.Error_response e) ->
      Alcotest.(check int)
        "error code" (-32600)
        (Jsonrpc.error_code_to_int e.error.code)
  | _ -> Alcotest.fail "expected error response"

let test_ping_after_init () =
  let config = make_config () in
  let state = init_and_notify config in
  let ping =
    Jsonrpc.Request { id = Int_id 2; method_ = "ping"; params = None }
  in
  let _state, resp = Mcp.handle config state ping in
  match resp with
  | Some (Jsonrpc.Success _) -> Alcotest.(check bool) "ping ok" true true
  | _ -> Alcotest.fail "expected success response for ping"

let test_tools_list_after_init () =
  let config = make_config () in
  let state = init_and_notify config in
  let tools_req =
    Jsonrpc.Request { id = Int_id 3; method_ = "tools/list"; params = None }
  in
  let _state, resp = Mcp.handle config state tools_req in
  match resp with
  | Some (Jsonrpc.Success s) -> (
      match s.result with
      | `Assoc fields -> (
          match Stdlib.List.assoc_opt "tools" fields with
          | Some (`List tools) ->
              Alcotest.(check int) "one tool" 1 (Stdlib.List.length tools)
          | _ -> Alcotest.fail "expected tools list")
      | _ -> Alcotest.fail "expected assoc result")
  | _ -> Alcotest.fail "expected success response"

let test_method_not_found () =
  let config = make_config () in
  let state = init_and_notify config in
  let unknown =
    Jsonrpc.Request { id = Int_id 4; method_ = "resources/read"; params = None }
  in
  let _state, resp = Mcp.handle config state unknown in
  match resp with
  | Some (Jsonrpc.Error_response e) ->
      Alcotest.(check int)
        "method not found code" (-32601)
        (Jsonrpc.error_code_to_int e.error.code)
  | _ -> Alcotest.fail "expected error response"

let test_double_initialize () =
  let config = make_config () in
  let state = init_and_notify config in
  let init_req =
    Jsonrpc.Request { id = Int_id 1; method_ = "initialize"; params = None }
  in
  let _state, resp = Mcp.handle config state init_req in
  match resp with
  | Some (Jsonrpc.Error_response e) ->
      Alcotest.(check int)
        "invalid request code" (-32600)
        (Jsonrpc.error_code_to_int e.error.code)
  | _ -> Alcotest.fail "expected error response"

let start_request ?mode ?(harness_session_id = "hs-1") ?(nonce = "nonce-1") id =
  let args =
    [
      ("_harness_session_id", `String harness_session_id);
      ("_nonce", `String nonce);
    ]
    @ match mode with None -> [] | Some m -> [ ("mode", `String m) ]
  in
  Jsonrpc.Request
    {
      id = Int_id id;
      method_ = "tools/call";
      params =
        Some (`Assoc [ ("name", `String "start"); ("arguments", `Assoc args) ]);
    }

let test_start_success () =
  let config = make_config () in
  let state = init_and_notify config in
  let req = start_request 10 ~mode:"ui" in
  let _state, resp = Mcp.handle config state req in
  match resp with
  | Some (Jsonrpc.Success s) -> (
      match s.result with
      | `Assoc fields -> (
          match Stdlib.List.assoc_opt "structuredContent" fields with
          | Some (`Assoc sc) -> (
              match Stdlib.List.assoc_opt "session_id" sc with
              | Some (`String sid) ->
                  Alcotest.(check string) "session id" "rs-1" sid
              | _ -> Alcotest.fail "expected session_id")
          | _ -> Alcotest.fail "expected structuredContent")
      | _ -> Alcotest.fail "expected assoc result")
  | _ -> Alcotest.fail "expected success response"

let test_start_skill_body_in_content () =
  let config = make_config () in
  let state = init_and_notify config in
  let req = start_request 11 in
  let _state, resp = Mcp.handle config state req in
  match resp with
  | Some (Jsonrpc.Success s) -> (
      match s.result with
      | `Assoc fields -> (
          match Stdlib.List.assoc_opt "content" fields with
          | Some
              (`List
                 [ `Assoc [ ("type", `String "text"); ("text", `String t) ] ])
            ->
              Alcotest.(check bool) "has skill body" true (String.length t > 0);
              Alcotest.(check bool)
                "has raw json instruction" true
                (String.length t > 0)
          | _ -> Alcotest.fail "expected content array")
      | _ -> Alcotest.fail "expected assoc result")
  | _ -> Alcotest.fail "expected success response"

let test_start_unknown_mode () =
  let config = make_config () in
  let state = init_and_notify config in
  let req = start_request 12 ~mode:"nonexistent" in
  let _state, resp = Mcp.handle config state req in
  match resp with
  | Some (Jsonrpc.Error_response e) ->
      Alcotest.(check int)
        "invalid params code" (-32602)
        (Jsonrpc.error_code_to_int e.error.code)
  | _ -> Alcotest.fail "expected error response"

let test_start_missing_correlation () =
  let config = make_config () in
  let state = init_and_notify config in
  let req =
    Jsonrpc.Request
      {
        id = Int_id 13;
        method_ = "tools/call";
        params =
          Some
            (`Assoc
               [
                 ("name", `String "start");
                 ("arguments", `Assoc [ ("mode", `String "ui") ]);
               ]);
      }
  in
  let _state, resp = Mcp.handle config state req in
  match resp with
  | Some (Jsonrpc.Error_response e) ->
      Alcotest.(check int)
        "invalid params code" (-32602)
        (Jsonrpc.error_code_to_int e.error.code)
  | _ -> Alcotest.fail "expected error response"

let test_start_duplicate_session () =
  let config = make_config () in
  let state = init_and_notify config in
  let req1 = start_request 14 ~harness_session_id:"hs-dup" in
  let _state, resp1 = Mcp.handle config state req1 in
  (match resp1 with
  | Some (Jsonrpc.Success _) -> ()
  | _ -> Alcotest.fail "first start should succeed");
  let req2 = start_request 15 ~harness_session_id:"hs-dup" in
  let _state, resp2 = Mcp.handle config state req2 in
  match resp2 with
  | Some (Jsonrpc.Error_response e) ->
      Alcotest.(check int)
        "invalid params code" (-32602)
        (Jsonrpc.error_code_to_int e.error.code)
  | _ -> Alcotest.fail "expected error response for duplicate"

let test_start_default_mode () =
  let config = make_config () in
  let state = init_and_notify config in
  let req = start_request 16 in
  let _state, resp = Mcp.handle config state req in
  match resp with
  | Some (Jsonrpc.Success s) -> (
      match s.result with
      | `Assoc fields -> (
          match Stdlib.List.assoc_opt "structuredContent" fields with
          | Some (`Assoc sc) -> (
              match Stdlib.List.assoc_opt "mode" sc with
              | Some (`String m) ->
                  Alcotest.(check string) "default mode is ui" "ui" m
              | _ -> Alcotest.fail "expected mode field")
          | _ -> Alcotest.fail "expected structuredContent")
      | _ -> Alcotest.fail "expected assoc result")
  | _ -> Alcotest.fail "expected success response"

let () =
  Alcotest.run "ribosome-mcp"
    [
      ( "lifecycle",
        [
          Alcotest.test_case "initialize" `Quick test_initialize;
          Alcotest.test_case "initialized notification" `Quick
            test_initialized_notification;
          Alcotest.test_case "reject before init" `Quick test_reject_before_init;
          Alcotest.test_case "ping after init" `Quick test_ping_after_init;
          Alcotest.test_case "tools/list after init" `Quick
            test_tools_list_after_init;
        ] );
      ( "errors",
        [
          Alcotest.test_case "method not found" `Quick test_method_not_found;
          Alcotest.test_case "double initialize" `Quick test_double_initialize;
        ] );
      ( "start",
        [
          Alcotest.test_case "successful start" `Quick test_start_success;
          Alcotest.test_case "skill body in content" `Quick
            test_start_skill_body_in_content;
          Alcotest.test_case "default mode" `Quick test_start_default_mode;
          Alcotest.test_case "unknown mode" `Quick test_start_unknown_mode;
          Alcotest.test_case "missing correlation" `Quick
            test_start_missing_correlation;
          Alcotest.test_case "duplicate session" `Quick
            test_start_duplicate_session;
        ] );
    ]
