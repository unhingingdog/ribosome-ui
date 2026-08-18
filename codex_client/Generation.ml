type completion =
  | Completed
  | Interrupted
  | Failed of string

type event =
  | Delta of {
      item_id: string;
      delta: string;
    }
  | Turn_finished of completion

type outcome =
  | Ignored
  | Routed of event

type error =
  | Invalid_notification of string
  | Duplicate_completion
  | Child_exited

type lifecycle =
  | Streaming
  | Finished

let ( let* ) = Result.bind

let required_string name fields =
  match Stdlib.List.assoc_opt name fields with
  | Some (`String value) -> Ok value
  | Some _ -> Error (Invalid_notification ("expected string: " ^ name))
  | None -> Error (Invalid_notification ("missing field: " ^ name))

let object_fields = function
  | `Assoc fields -> Ok fields
  | _ -> Error (Invalid_notification "expected notification object")

let matching_thread expected fields =
  let* thread_id = required_string "threadId" fields in
  Ok (thread_id = expected)

let route_delta thread_id turn_id params =
  let* fields = object_fields params in
  let* matches_thread = matching_thread thread_id fields in
  let* notification_turn_id = required_string "turnId" fields in
  if not matches_thread || notification_turn_id <> turn_id then Ok Ignored
  else
    let* item_id = required_string "itemId" fields in
    let* delta = required_string "delta" fields in
    Ok (Routed (Delta { item_id; delta }))

let route_completed thread_id turn_id params =
  let* fields = object_fields params in
  let* matches_thread = matching_thread thread_id fields in
  match Stdlib.List.assoc_opt "turn" fields with
  | Some (`Assoc turn_fields) ->
    let* notification_turn_id = required_string "id" turn_fields in
    if not matches_thread || notification_turn_id <> turn_id then Ok Ignored
    else
      let* status = required_string "status" turn_fields in
      (match status with
       | "completed" -> Ok (Routed (Turn_finished Completed))
       | "interrupted" -> Ok (Routed (Turn_finished Interrupted))
       | "failed" ->
         (match Stdlib.List.assoc_opt "error" turn_fields with
          | Some (`Assoc error_fields) ->
            let* message = required_string "message" error_fields in
            Ok (Routed (Turn_finished (Failed message)))
          | Some _ -> Error (Invalid_notification "expected object: turn.error")
          | None -> Error (Invalid_notification "missing field: turn.error"))
       | _ -> Error (Invalid_notification "unexpected turn.status"))
  | Some _ -> Error (Invalid_notification "expected object: turn")
  | None -> Error (Invalid_notification "missing field: turn")

let route thread turn = function
  | Client.Notification { method_ = "item/agentMessage/delta"; params = Some params } ->
    route_delta thread.Thread.id turn.Turn.id params
  | Client.Notification { method_ = "turn/completed"; params = Some params } ->
    route_completed thread.Thread.id turn.Turn.id params
  | Client.Notification { method_ = "item/agentMessage/delta"; params = None }
  | Client.Notification { method_ = "turn/completed"; params = None } ->
    Error (Invalid_notification "missing notification params")
  | Client.Notification _
  | Client.Response _
  | Client.Unexpected_response _
  | Client.Protocol_error _ -> Ok Ignored

let advance lifecycle outcome =
  match lifecycle, outcome with
  | Streaming, Routed (Turn_finished _) -> Ok (Finished, outcome)
  | Finished, Routed (Turn_finished _) -> Error Duplicate_completion
  | Streaming, Routed (Delta _) | Streaming, Ignored -> Ok (Streaming, outcome)
  | Finished, Routed (Delta _) | Finished, Ignored -> Ok (Finished, Ignored)

let child_exited = function
  | Streaming -> Error Child_exited
  | Finished -> Ok Finished
