open Ribosome_server_lib

let test_initialize () =
  let req =
    Jsonrpc.Request { id = Int_id 1; method_ = "initialize"; params = None }
  in
  let state, resp = Mcp.handle Mcp.Uninitialized req in
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
  let notif =
    Jsonrpc.Notification
      { method_ = "notifications/initialized"; params = None }
  in
  let state, resp = Mcp.handle Mcp.Uninitialized notif in
  Alcotest.(check string)
    "now initialized" "Initialized"
    (match state with Initialized -> "Initialized" | _ -> "wrong");
  Alcotest.(check bool) "no response for notification" true (resp = None)

let test_reject_before_init () =
  let req =
    Jsonrpc.Request { id = Int_id 2; method_ = "tools/list"; params = None }
  in
  let _state, resp = Mcp.handle Mcp.Uninitialized req in
  match resp with
  | Some (Jsonrpc.Error_response e) ->
      Alcotest.(check int)
        "error code" (-32600)
        (Jsonrpc.error_code_to_int e.error.code)
  | _ -> Alcotest.fail "expected error response"

let test_ping_after_init () =
  let init_req =
    Jsonrpc.Request { id = Int_id 1; method_ = "initialize"; params = None }
  in
  let notif =
    Jsonrpc.Notification
      { method_ = "notifications/initialized"; params = None }
  in
  let ping =
    Jsonrpc.Request { id = Int_id 2; method_ = "ping"; params = None }
  in
  let state, _ = Mcp.handle Mcp.Uninitialized init_req in
  let state, _ = Mcp.handle state notif in
  let _state, resp = Mcp.handle state ping in
  match resp with
  | Some (Jsonrpc.Success _) -> Alcotest.(check bool) "ping ok" true true
  | _ -> Alcotest.fail "expected success response for ping"

let test_tools_list_after_init () =
  let init_req =
    Jsonrpc.Request { id = Int_id 1; method_ = "initialize"; params = None }
  in
  let notif =
    Jsonrpc.Notification
      { method_ = "notifications/initialized"; params = None }
  in
  let tools_req =
    Jsonrpc.Request { id = Int_id 3; method_ = "tools/list"; params = None }
  in
  let state, _ = Mcp.handle Mcp.Uninitialized init_req in
  let state, _ = Mcp.handle state notif in
  let _state, resp = Mcp.handle state tools_req in
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
  let init_req =
    Jsonrpc.Request { id = Int_id 1; method_ = "initialize"; params = None }
  in
  let notif =
    Jsonrpc.Notification
      { method_ = "notifications/initialized"; params = None }
  in
  let unknown =
    Jsonrpc.Request { id = Int_id 4; method_ = "resources/read"; params = None }
  in
  let state, _ = Mcp.handle Mcp.Uninitialized init_req in
  let state, _ = Mcp.handle state notif in
  let _state, resp = Mcp.handle state unknown in
  match resp with
  | Some (Jsonrpc.Error_response e) ->
      Alcotest.(check int)
        "method not found code" (-32601)
        (Jsonrpc.error_code_to_int e.error.code)
  | _ -> Alcotest.fail "expected error response"

let test_double_initialize () =
  let init_req =
    Jsonrpc.Request { id = Int_id 1; method_ = "initialize"; params = None }
  in
  let notif =
    Jsonrpc.Notification
      { method_ = "notifications/initialized"; params = None }
  in
  let state, _ = Mcp.handle Mcp.Uninitialized init_req in
  let state, _ = Mcp.handle state notif in
  let _state, resp = Mcp.handle state init_req in
  match resp with
  | Some (Jsonrpc.Error_response e) ->
      Alcotest.(check int)
        "invalid request code" (-32600)
        (Jsonrpc.error_code_to_int e.error.code)
  | _ -> Alcotest.fail "expected error response"

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
    ]
