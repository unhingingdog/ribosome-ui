open Codex_client

let assert_equal label expected actual =
  if expected <> actual then failwith label

let client_info = Initialize.{ name = "ribosome-dream"; title = None; version = "0.1.0" }
let capabilities = Initialize.{ experimental_api = false; request_attestation = false }

let test_starts_initialize_request () =
  match Initialize.start Initialize.Not_started (Client.create ()) client_info capabilities with
  | Ok (Client.Send_line line, client, Initialize.Waiting (Codex_protocol.JsonRpc.Integer 1)) ->
    assert_equal "initialize request has client identity and capabilities"
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"clientInfo\":{\"name\":\"ribosome-dream\",\"title\":null,\"version\":\"0.1.0\"},\"capabilities\":{\"experimentalApi\":false,\"requestAttestation\":false}}}"
      line;
    assert_equal "initialize request is pending" 1 (Stdlib.List.length client.pending)
  | Ok _ | Error _ -> failwith "expected initialize command"

let test_completes_initialize () =
  let event = Client.Response {
    request = { Client.id = Codex_protocol.JsonRpc.Integer 1; method_ = "initialize" };
    result = Ok (`Assoc [
      ("userAgent", `String "codex/1.0");
      ("codexHome", `String "/home/codex");
      ("platformFamily", `String "unix");
      ("platformOs", `String "linux");
    ]);
  } in
  match Initialize.receive (Initialize.Waiting (Codex_protocol.JsonRpc.Integer 1)) event with
  | Ok ([Client.Send_line "{\"jsonrpc\":\"2.0\",\"method\":\"initialized\"}"], Initialize.Ready server) ->
    assert_equal "server platform is retained" "linux" server.platform_os
  | Ok _ | Error _ -> failwith "expected initialized notification"

let test_rejects_invalid_order () =
  assert_equal "cannot initialize twice" (Error Initialize.Already_started)
    (Initialize.start (Initialize.Waiting (Codex_protocol.JsonRpc.Integer 1)) (Client.create ()) client_info capabilities);
  assert_equal "cannot complete before starting" (Error Initialize.Unexpected_event)
    (Initialize.receive Initialize.Not_started (Client.Notification { method_ = "delta"; params = None }))

let () =
  test_starts_initialize_request ();
  test_completes_initialize ();
  test_rejects_invalid_order ()
