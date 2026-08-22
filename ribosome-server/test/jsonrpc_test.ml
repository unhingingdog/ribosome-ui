open Ribosome_server_lib

let encode_str msg = Jsonrpc.encode_to_line msg

let test_request () =
  let msg =
    Jsonrpc.Request { id = Int_id 1; method_ = "ping"; params = None }
  in
  let line = encode_str msg in
  Alcotest.(check string)
    "request line" {json|{"jsonrpc":"2.0","id":1,"method":"ping"}
|json} line;
  match Jsonrpc.decode_line line with
  | Ok (Jsonrpc.Request r) ->
      Alcotest.(check string) "method" "ping" r.method_;
      Alcotest.(check string)
        "id" "1"
        (match r.id with Int_id n -> string_of_int n | _ -> "wrong")
  | _ -> Alcotest.fail "expected Request"

let test_notification () =
  let msg = Jsonrpc.Notification { method_ = "initialized"; params = None } in
  let line = encode_str msg in
  Alcotest.(check string)
    "notification line" {json|{"jsonrpc":"2.0","method":"initialized"}
|json}
    line;
  match Jsonrpc.decode_line line with
  | Ok (Jsonrpc.Notification n) ->
      Alcotest.(check string) "method" "initialized" n.method_
  | _ -> Alcotest.fail "expected Notification"

let test_request_with_params () =
  let msg =
    Jsonrpc.Request
      {
        id = String_id "abc";
        method_ = "tools/call";
        params = Some (`Assoc [ ("name", `String "start") ]);
      }
  in
  let line = encode_str msg in
  match Jsonrpc.decode_line line with
  | Ok (Jsonrpc.Request r) ->
      Alcotest.(check string) "method" "tools/call" r.method_;
      Alcotest.(check string)
        "id" "abc"
        (match r.id with String_id s -> s | _ -> "wrong");
      Alcotest.(check bool) "has params" true (r.params <> None)
  | _ -> Alcotest.fail "expected Request"

let test_success_response () =
  let msg = Jsonrpc.make_success_response (Int_id 2) (`String "ok") in
  let line = encode_str msg in
  Alcotest.(check string)
    "success line" {json|{"jsonrpc":"2.0","id":2,"result":"ok"}
|json} line;
  match Jsonrpc.decode_line line with
  | Ok (Jsonrpc.Success s) ->
      Alcotest.(check string)
        "id" "2"
        (match s.id with Int_id n -> string_of_int n | _ -> "wrong")
  | _ -> Alcotest.fail "expected Success"

let test_error_response () =
  let msg =
    Jsonrpc.make_error_response (Int_id 3) Jsonrpc.Method_not_found
      "no such method"
  in
  let line = encode_str msg in
  Alcotest.(check string)
    "error line"
    {json|{"jsonrpc":"2.0","id":3,"error":{"code":-32601,"message":"no such method"}}
|json}
    line;
  match Jsonrpc.decode_line line with
  | Ok (Jsonrpc.Error_response e) ->
      Alcotest.(check int)
        "error code" (-32601)
        (Jsonrpc.error_code_to_int e.error.code)
  | _ -> Alcotest.fail "expected Error_response"

let test_both_result_and_error_rejected () =
  let json =
    `Assoc
      [
        ("jsonrpc", `String "2.0");
        ("id", `Int 1);
        ("result", `Null);
        ("error", `Assoc [ ("code", `Int (-1)); ("message", `String "x") ]);
      ]
  in
  match Jsonrpc.decode_message json with
  | Ok _ -> Alcotest.fail "should reject both result and error"
  | Error e -> Alcotest.(check bool) "mentions both" true (String.length e > 0)

let test_malformed_json () =
  match Jsonrpc.decode_line "{not json}" with
  | Ok _ -> Alcotest.fail "should reject malformed json"
  | Error _ -> Alcotest.(check bool) "error returned" true true

let test_correlation () =
  let req =
    Jsonrpc.Request { id = Int_id 42; method_ = "ping"; params = None }
  in
  let line = encode_str req in
  match Jsonrpc.decode_line line with
  | Ok (Jsonrpc.Request r) -> (
      Alcotest.(check int)
        "id preserved" 42
        (match r.id with Int_id n -> n | _ -> 0);
      let resp = Jsonrpc.make_success_response r.id `Null in
      let resp_line = encode_str resp in
      match Jsonrpc.decode_line resp_line with
      | Ok (Jsonrpc.Success s) ->
          Alcotest.(check int)
            "response id matches" 42
            (match s.id with Int_id n -> n | _ -> 0)
      | _ -> Alcotest.fail "expected Success response")
  | _ -> Alcotest.fail "expected Request"

let test_error_with_data () =
  let msg =
    Jsonrpc.Error_response
      {
        id = Int_id 5;
        error =
          {
            code = Jsonrpc.Invalid_params;
            message = "missing field";
            data = Some (`Assoc [ ("field", `String "mode") ]);
          };
      }
  in
  let line = encode_str msg in
  match Jsonrpc.decode_line line with
  | Ok (Jsonrpc.Error_response e) ->
      Alcotest.(check bool) "has data" true (e.error.data <> None)
  | _ -> Alcotest.fail "expected Error_response"

let () =
  Alcotest.run "ribosome-jsonrpc"
    [
      ( "messages",
        [
          Alcotest.test_case "request" `Quick test_request;
          Alcotest.test_case "notification" `Quick test_notification;
          Alcotest.test_case "request with params" `Quick
            test_request_with_params;
          Alcotest.test_case "success response" `Quick test_success_response;
          Alcotest.test_case "error response" `Quick test_error_response;
          Alcotest.test_case "error with data" `Quick test_error_with_data;
        ] );
      ( "validation",
        [
          Alcotest.test_case "both result and error rejected" `Quick
            test_both_result_and_error_rejected;
          Alcotest.test_case "malformed json" `Quick test_malformed_json;
        ] );
      ( "correlation",
        [
          Alcotest.test_case "request-response correlation" `Quick
            test_correlation;
        ] );
    ]
