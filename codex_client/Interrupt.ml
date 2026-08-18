type phase =
  | Idle
  | Active
  | Waiting of Codex_protocol.JsonRpc.request_id
  | Interrupted

type error =
  | No_active_turn
  | Already_interrupted
  | Unexpected_event
  | Server_error of Codex_protocol.JsonRpc.error

type outcome =
  | Requested of Client.command
  | Interrupt_confirmed

let params thread turn =
  `Assoc [
    ("threadId", `String thread.Thread.id);
    ("turnId", `String turn.Turn.id);
  ]

let start phase client thread turn =
  match phase with
  | Idle -> Error No_active_turn
  | Waiting _ | Interrupted -> Error Already_interrupted
  | Active ->
    let pending, command, client = Client.request client "turn/interrupt" (Some (params thread turn)) in
    Ok (Requested command, client, Waiting pending.id)

let receive phase client event =
  match phase, event with
  | Waiting id, Client.Response { request; result = Ok _ }
    when request.id = id && request.method_ = "turn/interrupt" ->
    Ok (Interrupt_confirmed, client, Interrupted)
  | Waiting id, Client.Response { request; result = Error error }
    when request.id = id && request.method_ = "turn/interrupt" -> Error (Server_error error)
  | Idle, _ | Active, _ | Waiting _, _ | Interrupted, _ -> Error Unexpected_event
