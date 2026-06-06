type send_payload = { prompt: string }
type recv_payload = { chunk: string }

type idle
type sending
type receiving
type errored

type _ failed = 
  | FailedSend : send_payload -> sending failed
  | FailedRecv : recv_payload -> receiving failed

type system_error = {
  details: string;
}

type _ state = 
  | Idle : idle state
  | Sending : send_payload -> sending state
  | Receiving : recv_payload -> receiving state
  | Err : system_error * 'a failed -> errored state


type send_action =
  | Send of send_payload

type start_recv_action = 
  | StartRecv of recv_payload
  | ErrOut of string

type continue_recv_action =
  | Continue of recv_payload
  | Complete
  | ErrOut of string

type recover_action =
  | Retry
  | Restart

(* every transition returns a result *)

type idle_result =
  | StartSending of sending state

type sending_result = 
  | StartReceiving of receiving state
  | SendErr of errored state

type receiving_result = 
  | ContinueReceiving of receiving state
  | Done of idle state
  | RecvErr of errored state

type recover_result = 
  | RetrySend of sending state
  | RetryRecv of receiving state
  | Restarted of idle state

(* these are all legal transitions *)

let transition_idle (state: idle state) (action: send_action) : idle_result =
  match state, action with 
  | Idle, Send payload -> StartSending (Sending payload)

let transition_sending (state: sending state) (action: start_recv_action): sending_result =
  match state, action with
    | Sending _, StartRecv payload ->
      StartReceiving (Receiving payload)
    | Sending payload, ErrOut details ->
      SendErr (Err ({ details }, FailedSend payload))

let transition_receiving (state: receiving state) (action: continue_recv_action): receiving_result =
  match state, action with
    | Receiving _, Continue payload ->
      ContinueReceiving (Receiving payload)
    | Receiving _, Complete ->
      Done Idle
    | Receiving payload, ErrOut details ->
      RecvErr (Err ({ details }, FailedRecv payload))

let transition_errored (state: errored state) (action: recover_action): recover_result =
  match state, action with
    | Err (_, _), Restart ->
      Restarted Idle
    | Err (_, FailedSend payload), Retry ->
      RetrySend (Sending payload)
    | Err (_, FailedRecv payload), Retry ->
      RetryRecv (Receiving payload)

(* These are adapters that handled the necsesary widened types when we keep this machine statefully. *)

type any_state = AnyState : 'phase state -> any_state

let state_of_idle_result = function
  | StartSending state -> AnyState state

let state_of_sending_result = function
  | StartReceiving state -> AnyState state
  | SendErr state -> AnyState state

let state_of_receiving_result = function
  | ContinueReceiving state -> AnyState state
  | Done state -> AnyState state
  | RecvErr state -> AnyState state

let state_of_recover_result = function
  | RetrySend state -> AnyState state
  | RetryRecv state -> AnyState state
  | Restarted state -> AnyState state

let restart (AnyState state) =
  match state with
  | Err (_, _) ->
    (match transition_errored state Restart with
     | Restarted idle -> AnyState idle
     | RetrySend sending -> AnyState sending
     | RetryRecv receiving -> AnyState receiving)
  | Idle | Sending _ | Receiving _ -> AnyState state

let kick_off (AnyState state) ~prompt =
  match state with
  | Idle ->
    transition_idle state (Send { prompt })
    |> state_of_idle_result
    |> Result.ok
  | Sending _ | Receiving _ ->
    Error "Cannot kick off while a request is already in flight"
  | Err (error, _) ->
    Error ("Cannot kick off while engine is errored: " ^ error.details)

let receive_chunk (AnyState state) ~chunk =
  match state with
  | Sending _ ->
    transition_sending state (StartRecv { chunk })
    |> state_of_sending_result
    |> Result.ok
  | Receiving _ ->
    transition_receiving state (Continue { chunk })
    |> state_of_receiving_result
    |> Result.ok
  | Idle ->
    Error "Cannot receive a chunk before kick off"
  | Err (error, _) ->
    Error ("Cannot receive while engine is errored: " ^ error.details)

let complete (AnyState state) =
  match state with
  | Receiving _ ->
    transition_receiving state Complete
    |> state_of_receiving_result
    |> Result.ok
  | Idle -> Error "Cannot complete while engine is idle"
  | Sending _ -> Error "Cannot complete before receiving a chunk"
  | Err (error, _) -> Error ("Cannot complete while engine is errored: " ^ error.details)

let fail (AnyState state) details =
  match state with
  | Sending _ ->
    transition_sending state (ErrOut details)
    |> state_of_sending_result
  | Receiving _ ->
    transition_receiving state (ErrOut details)
    |> state_of_receiving_result
  | Idle | Err _ -> AnyState state
