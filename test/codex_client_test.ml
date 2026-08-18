open Codex_client

let assert_equal label expected actual =
  if expected <> actual then failwith label

let test_assigns_request_ids () =
  let command, state = Client.request (Client.create ()) "initialize" None in
  assert_equal "request is encoded as a JSON-RPC line"
    (Client.Send_line "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\"}") command;
  assert_equal "request is pending"
    [{ Client.id = Codex_protocol.JsonRpc.Integer 1; method_ = "initialize" }]
    state.pending

let test_correlates_response () =
  let _, requested = Client.request (Client.create ()) "initialize" None in
  let event, state = Client.receive requested
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"ready\":true}}" in
  assert_equal "response is matched to its request"
    (Client.Response {
      request = { id = Codex_protocol.JsonRpc.Integer 1; method_ = "initialize" };
      result = Ok (`Assoc [("ready", `Bool true)]);
    }) event;
  assert_equal "matched request is removed" [] state.pending

let test_preserves_state_for_notifications () =
  let state = Client.create () in
  let event, next = Client.receive state
    "{\"jsonrpc\":\"2.0\",\"method\":\"item/agentMessage/delta\",\"params\":{\"delta\":\"{\"}}" in
  assert_equal "notification is forwarded"
    (Client.Notification {
      method_ = "item/agentMessage/delta";
      params = Some (`Assoc [("delta", `String "{")]);
    }) event;
  assert_equal "notification preserves client state" state next

let test_rejects_unknown_responses () =
  let state = Client.create () in
  let event, next = Client.receive state
    "{\"jsonrpc\":\"2.0\",\"id\":99,\"result\":{}}" in
  assert_equal "unknown response is surfaced"
    (Client.Unexpected_response (Some (Codex_protocol.JsonRpc.Integer 99))) event;
  assert_equal "unknown response preserves state" state next

let () =
  test_assigns_request_ids ();
  test_correlates_response ();
  test_preserves_state_for_notifications ();
  test_rejects_unknown_responses ()
