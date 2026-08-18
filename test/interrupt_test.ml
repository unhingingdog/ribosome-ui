open Codex_client

let assert_equal label expected actual =
  if expected <> actual then failwith label

let thread = Thread.{ id = "thread-1" }
let turn = Turn.{ id = "turn-1" }

let test_interrupts_active_turn () =
  match Interrupt.start Interrupt.Active (Client.create ()) thread turn with
  | Ok (Interrupt.Requested (Client.Send_line line), _, Interrupt.Waiting _) ->
    assert_equal "interrupt is correlated to the active turn"
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"turn/interrupt\",\"params\":{\"threadId\":\"thread-1\",\"turnId\":\"turn-1\"}}"
      line
  | Ok _ | Error _ -> failwith "expected turn/interrupt command"

let test_records_interrupt_failure () =
  let error = Codex_protocol.JsonRpc.{ code = -1; message = "interruption failed"; data = None } in
  let event = Client.Response {
    request = { Client.id = Codex_protocol.JsonRpc.Integer 1; method_ = "turn/interrupt" };
    result = Error error;
  } in
  assert_equal "interrupt RPC errors remain visible"
    (Error (Interrupt.Server_error error))
    (Interrupt.receive (Interrupt.Waiting (Codex_protocol.JsonRpc.Integer 1)) (Client.create ()) event)

let () =
  test_interrupts_active_turn ();
  test_records_interrupt_failure ()
