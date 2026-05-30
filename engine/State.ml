type send_payload = { prompt: string }
type recv_payload = { chunk: string }

type message = User of string | Bot of string

type history = {
  messages: message list
}

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
  | Idle : history -> idle state
  | Sending : history * send_payload -> sending state
  | Receiving : history * recv_payload -> receiving state
  | Err : history * system_error * 'a failed -> errored state


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


let transition_idle (state: idle state) (action: send_action) : idle_result =
  match state, action with 
  | Idle history, Send payload -> StartSending (Sending (history, payload))

let transition_sending (state: sending state) (action: start_recv_action): sending_result =
  match state, action with
    | Sending (history, _), StartRecv payload ->
      StartReceiving (Receiving (history, payload))
    | Sending (history, payload), ErrOut details ->
      SendErr (Err (history, { details }, FailedSend payload))

let transition_receiving (state: receiving state) (action: continue_recv_action): receiving_result =
  match state, action with
    | Receiving (history, _), Continue payload ->
      ContinueReceiving (Receiving (history, payload))
    | Receiving (history, _), Complete ->
      Done (Idle history)
    | Receiving (history, payload), ErrOut details ->
      RecvErr (Err (history, { details }, FailedRecv payload))

let transition_errored (state: errored state) (action: recover_action): recover_result =
  match state, action with
    | Err (_, _, _), Restart ->
      Restarted (Idle { messages = [] })
    | Err (history, _, FailedSend payload), Retry ->
      RetrySend (Sending (history, payload))
    | Err (history, _, FailedRecv payload), Retry ->
      RetryRecv (Receiving (history, payload))
