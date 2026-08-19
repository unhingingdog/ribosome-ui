open Codex_protocol

let assert_equal label expected actual =
  if expected <> actual then failwith label

let test_encodes_request () =
  let request = JsonRpc.{
    id = Integer 1;
    method_ = "initialize";
    params = Some (`Assoc [("client", `String "dream")]);
  } in
  assert_equal "request has JSON-RPC envelope"
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"client\":\"dream\"}}"
    (Melange_json.to_string (JsonRpc.encode_request request))

let test_decodes_result_response () =
  assert_equal "result response is correlated by id"
    (Ok (JsonRpc.Response {
      id = Some (JsonRpc.Integer 7);
      result = Ok (`Assoc [("status", `String "ready")]);
    }))
    (JsonRpc.decode_string_inbound
      "{\"jsonrpc\":\"2.0\",\"id\":7,\"result\":{\"status\":\"ready\"}}")

let test_decodes_codex_response_without_version () =
  assert_equal "Codex app-server response is correlated by id"
    (Ok (JsonRpc.Response {
      id = Some (JsonRpc.Integer 7);
      result = Ok (`Assoc [("status", `String "ready")]);
    }))
    (JsonRpc.decode_string_inbound
      "{\"id\":7,\"result\":{\"status\":\"ready\"}}")

let test_decodes_error_response () =
  assert_equal "error response is decoded"
    (Ok (JsonRpc.Response {
      id = Some (JsonRpc.String "turn-3");
      result = Error { code = -32601; message = "Method not found"; data = None };
    }))
    (JsonRpc.decode_string_inbound
      "{\"jsonrpc\":\"2.0\",\"id\":\"turn-3\",\"error\":{\"code\":-32601,\"message\":\"Method not found\"}}")

let test_decodes_notification () =
  assert_equal "assistant delta is a notification"
    (Ok (JsonRpc.Notification {
      method_ = "item/agentMessage/delta";
      params = Some (`Assoc [("delta", `String "{")]);
    }))
    (JsonRpc.decode_string_inbound
      "{\"jsonrpc\":\"2.0\",\"method\":\"item/agentMessage/delta\",\"params\":{\"delta\":\"{\"}}")

let test_rejects_invalid_envelopes () =
  assert_equal "wrong protocol version is rejected" (Error "expected JSON-RPC version 2.0")
    (JsonRpc.decode_string_inbound "{\"jsonrpc\":\"1.0\",\"method\":\"delta\"}");
  assert_equal "response requires one outcome" (Error "JSON-RPC response has neither result nor error")
    (JsonRpc.decode_string_inbound "{\"jsonrpc\":\"2.0\",\"id\":1}")

let () =
  test_encodes_request ();
  test_decodes_result_response ();
  test_decodes_codex_response_without_version ();
  test_decodes_error_response ();
  test_decodes_notification ();
  test_rejects_invalid_envelopes ()
