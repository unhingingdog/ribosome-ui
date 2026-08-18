type event =
  | Delta of {
      item_id: string;
      delta: string;
    }
  | Completed

type outcome =
  | Ignored
  | Routed of event

type error = Invalid_notification of string

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
    if matches_thread && notification_turn_id = turn_id then Ok (Routed Completed)
    else Ok Ignored
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
