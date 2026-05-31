let assert_true label condition =
  if not condition then failwith label

let assert_equal label expected actual =
  assert_true label (expected = actual)

let send_payload = { State.prompt = "make ui" }
let recv_payload = { State.chunk = "data" }
let next_recv_payload = { State.chunk = "more data" }

let test_transition_idle () =
  match State.transition_idle State.Idle (State.Send send_payload) with
  | State.StartSending (State.Sending next_payload) ->
    assert_equal "idle stores send payload" send_payload next_payload
  | State.StartSending _ ->
    failwith "expected Sending state"

let test_transition_sending_start_recv () =
  let state = State.Sending send_payload in
  match State.transition_sending state (State.StartRecv recv_payload) with
  | State.StartReceiving (State.Receiving next_payload) ->
    assert_equal "sending stores recv payload" recv_payload next_payload
  | State.StartReceiving _ ->
    failwith "expected Receiving state"
  | State.SendErr _ ->
    failwith "expected StartReceiving"

let test_transition_sending_error () =
  let state = State.Sending send_payload in
  match State.transition_sending state (State.ErrOut "send failed") with
  | State.SendErr (State.Err (error, State.FailedSend failed_payload)) ->
    assert_equal "send error stores details" "send failed" error.details;
    assert_equal "send error stores failed payload" send_payload failed_payload
  | State.SendErr _ ->
    failwith "expected FailedSend error"
  | State.StartReceiving _ ->
    failwith "expected SendErr"

let test_transition_receiving_continue () =
  let state = State.Receiving recv_payload in
  match State.transition_receiving state (State.Continue next_recv_payload) with
  | State.ContinueReceiving (State.Receiving next_payload) ->
    assert_equal "continue replaces recv payload" next_recv_payload next_payload
  | State.ContinueReceiving _ ->
    failwith "expected Receiving state"
  | State.Done _ | State.RecvErr _ ->
    failwith "expected ContinueReceiving"

let test_transition_receiving_complete () =
  let state = State.Receiving recv_payload in
  match State.transition_receiving state State.Complete with
  | State.Done State.Idle -> ()
  | State.Done _ ->
    failwith "expected Idle state"
  | State.ContinueReceiving _ | State.RecvErr _ ->
    failwith "expected Done"

let test_transition_receiving_error () =
  let state = State.Receiving recv_payload in
  match State.transition_receiving state (State.ErrOut "recv failed") with
  | State.RecvErr (State.Err (error, State.FailedRecv failed_payload)) ->
    assert_equal "recv error stores details" "recv failed" error.details;
    assert_equal "recv error stores failed payload" recv_payload failed_payload
  | State.RecvErr _ ->
    failwith "expected FailedRecv error"
  | State.ContinueReceiving _ | State.Done _ ->
    failwith "expected RecvErr"

let test_transition_errored_retry_send () =
  let state = State.Err ({ State.details = "send failed" }, State.FailedSend send_payload) in
  match State.transition_errored state State.Retry with
  | State.RetrySend (State.Sending next_payload) ->
    assert_equal "retry send restores payload" send_payload next_payload
  | State.RetrySend _ ->
    failwith "expected Sending state"
  | State.RetryRecv _ | State.Restarted _ ->
    failwith "expected RetrySend"

let test_transition_errored_retry_recv () =
  let state = State.Err ({ State.details = "recv failed" }, State.FailedRecv recv_payload) in
  match State.transition_errored state State.Retry with
  | State.RetryRecv (State.Receiving next_payload) ->
    assert_equal "retry recv restores payload" recv_payload next_payload
  | State.RetryRecv _ ->
    failwith "expected Receiving state"
  | State.RetrySend _ | State.Restarted _ ->
    failwith "expected RetryRecv"

let test_transition_errored_restart () =
  let state = State.Err ({ State.details = "failed" }, State.FailedRecv recv_payload) in
  match State.transition_errored state State.Restart with
  | State.Restarted State.Idle -> ()
  | State.Restarted _ ->
    failwith "expected Idle state"
  | State.RetrySend _ | State.RetryRecv _ ->
    failwith "expected Restarted"

let test_state_of_idle_result () =
  let result = State.transition_idle State.Idle (State.Send send_payload) in
  match State.state_of_idle_result result with
  | State.AnyState (State.Sending next_payload) ->
    assert_equal "idle adapter stores send payload" send_payload next_payload
  | State.AnyState _ ->
    failwith "expected Sending state"

let test_state_of_sending_result () =
  let result =
    State.transition_sending
      (State.Sending send_payload)
      (State.StartRecv recv_payload)
  in
  match State.state_of_sending_result result with
  | State.AnyState (State.Receiving next_payload) ->
    assert_equal "sending adapter stores recv payload" recv_payload next_payload
  | State.AnyState _ ->
    failwith "expected Receiving state"

let test_state_of_receiving_result () =
  let result = State.transition_receiving (State.Receiving recv_payload) State.Complete in
  match State.state_of_receiving_result result with
  | State.AnyState State.Idle -> ()
  | State.AnyState _ ->
    failwith "expected Idle state"

let test_state_of_recover_result () =
  let state = State.Err ({ State.details = "failed" }, State.FailedSend send_payload) in
  let result = State.transition_errored state State.Retry in
  match State.state_of_recover_result result with
  | State.AnyState (State.Sending next_payload) ->
    assert_equal "recover adapter restores send payload" send_payload next_payload
  | State.AnyState _ ->
    failwith "expected Sending state"

let test_kick_off () =
  match State.kick_off (State.AnyState State.Idle) ~prompt:"make ui" with
  | Ok (State.AnyState (State.Sending payload)) ->
    assert_equal "kick_off stores prompt" "make ui" payload.prompt
  | Ok (State.AnyState _) ->
    failwith "expected Sending state"
  | Error message ->
    failwith message

let test_kick_off_rejects_in_flight () =
  match State.kick_off (State.AnyState (State.Sending send_payload)) ~prompt:"again" with
  | Ok _ -> failwith "expected kick_off rejection"
  | Error _ -> ()

let test_receive_chunk_starts_receiving () =
  match State.receive_chunk (State.AnyState (State.Sending send_payload)) ~chunk:"data" with
  | Ok (State.AnyState (State.Receiving payload)) ->
    assert_equal "receive_chunk stores first chunk" "data" payload.chunk
  | Ok (State.AnyState _) ->
    failwith "expected Receiving state"
  | Error message ->
    failwith message

let test_receive_chunk_continues_receiving () =
  match State.receive_chunk (State.AnyState (State.Receiving recv_payload)) ~chunk:"more" with
  | Ok (State.AnyState (State.Receiving payload)) ->
    assert_equal "receive_chunk replaces chunk" "more" payload.chunk
  | Ok (State.AnyState _) ->
    failwith "expected Receiving state"
  | Error message ->
    failwith message

let test_complete () =
  match State.complete (State.AnyState (State.Receiving recv_payload)) with
  | Ok (State.AnyState State.Idle) -> ()
  | Ok (State.AnyState _) ->
    failwith "expected Idle state"
  | Error message ->
    failwith message

let test_fail_from_sending () =
  match State.fail (State.AnyState (State.Sending send_payload)) "send failed" with
  | State.AnyState (State.Err (error, State.FailedSend payload)) ->
    assert_equal "fail stores send error" "send failed" error.details;
    assert_equal "fail stores send payload" send_payload payload
  | State.AnyState _ ->
    failwith "expected send error state"

let test_fail_from_receiving () =
  match State.fail (State.AnyState (State.Receiving recv_payload)) "recv failed" with
  | State.AnyState (State.Err (error, State.FailedRecv payload)) ->
    assert_equal "fail stores recv error" "recv failed" error.details;
    assert_equal "fail stores recv payload" recv_payload payload
  | State.AnyState _ ->
    failwith "expected recv error state"

let () =
  test_transition_idle ();
  test_transition_sending_start_recv ();
  test_transition_sending_error ();
  test_transition_receiving_continue ();
  test_transition_receiving_complete ();
  test_transition_receiving_error ();
  test_transition_errored_retry_send ();
  test_transition_errored_retry_recv ();
  test_transition_errored_restart ();
  test_state_of_idle_result ();
  test_state_of_sending_result ();
  test_state_of_receiving_result ();
  test_state_of_recover_result ();
  test_kick_off ();
  test_kick_off_rejects_in_flight ();
  test_receive_chunk_starts_receiving ();
  test_receive_chunk_continues_receiving ();
  test_complete ();
  test_fail_from_sending ();
  test_fail_from_receiving ()
