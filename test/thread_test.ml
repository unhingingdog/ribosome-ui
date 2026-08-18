open Codex_client

let assert_equal label expected actual =
  if expected <> actual then failwith label

let configuration = Thread.{ cwd = "/opt/ribosome"; model = None }

let test_starts_restricted_thread () =
  match Thread.start Thread.Idle (Client.create ()) configuration with
  | Ok (Thread.Requested (Client.Send_line line), _, Thread.Waiting _) ->
    assert_equal "thread start disables approval and writes"
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"thread/start\",\"params\":{\"cwd\":\"/opt/ribosome\",\"approvalPolicy\":\"never\",\"sandbox\":\"read-only\"}}"
      line
  | Ok _ | Error _ -> failwith "expected thread/start command"

let test_resumes_restricted_thread () =
  match Thread.resume Thread.Idle (Client.create ()) configuration "thread-1" with
  | Ok (Thread.Requested (Client.Send_line line), _, Thread.Waiting _) ->
    assert_equal "thread resume retains restrictions"
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"thread/resume\",\"params\":{\"threadId\":\"thread-1\",\"cwd\":\"/opt/ribosome\",\"approvalPolicy\":\"never\",\"sandbox\":\"read-only\"}}"
      line
  | Ok _ | Error _ -> failwith "expected thread/resume command"

let test_records_thread_id () =
  let phase = Thread.Waiting { id = Codex_protocol.JsonRpc.Integer 1; method_ = "thread/start" } in
  let event = Client.Response {
    request = { Client.id = Codex_protocol.JsonRpc.Integer 1; method_ = "thread/start" };
    result = Ok (`Assoc [("thread", `Assoc [("id", `String "thread-1")])]);
  } in
  assert_equal "thread id is available to Dream"
    (Ok (Thread.Thread_ready { id = "thread-1" }, Client.create (), Thread.Active { id = "thread-1" }))
    (Thread.receive phase (Client.create ()) event)

let test_rejects_second_thread () =
  assert_equal "one active thread per session" (Error Thread.Already_active)
    (Thread.start (Thread.Active { id = "thread-1" }) (Client.create ()) configuration)

let () =
  test_starts_restricted_thread ();
  test_resumes_restricted_thread ();
  test_records_thread_id ();
  test_rejects_second_thread ()
