type value = Ribosome_core.Types.input_value

type component_event =
  | Click of { id: string }
  | Change of { id: string; value: value }
  | Submit of { id: string; values: (string * value) list }

type t =
  | New_session
  | Resume_session of { session_id: string }
  | Component_event of {
      session_id: string;
      event_id: string;
      base_revision: int;
      event: component_event;
    }
  | Cancel of { session_id: string }

type error = string

let protocol_version = 1
let ( let* ) = Result.bind

let encode_value = function
  | Ribosome_core.Types.String value -> `String value
  | Ribosome_core.Types.Int value -> `Int value

let decode_value = function
  | `String value -> Ok (Ribosome_core.Types.String value)
  | `Int value -> Ok (Ribosome_core.Types.Int value)
  | _ -> Error "expected string or integer value"

let object_fields = function
  | `Assoc fields -> Ok fields
  | _ -> Error "expected message object"

let required name decoder fields =
  match Stdlib.List.assoc_opt name fields with
  | Some value -> decoder value
  | None -> Error ("missing field: " ^ name)

let string = function
  | `String value -> Ok value
  | _ -> Error "expected string"

let integer = function
  | `Int value -> Ok value
  | _ -> Error "expected integer"

let decode_values = function
  | `List values ->
    let rec loop decoded = function
      | [] -> Ok (Stdlib.List.rev decoded)
      | value :: remaining ->
        let* fields = object_fields value in
        let* id = required "id" string fields in
        let* value = required "value" decode_value fields in
        loop ((id, value) :: decoded) remaining
    in
    loop [] values
  | _ -> Error "expected values array"

let encode_event = function
  | Click { id } -> `Assoc [("type", `String "click"); ("id", `String id)]
  | Change { id; value } -> `Assoc [
      ("type", `String "change");
      ("id", `String id);
      ("value", encode_value value);
    ]
  | Submit { id; values } -> `Assoc [
      ("type", `String "submit");
      ("id", `String id);
      ("values", `List (Stdlib.List.map (fun (id, value) -> `Assoc [
        ("id", `String id);
        ("value", encode_value value);
      ]) values));
    ]

let decode_event value =
  let* fields = object_fields value in
  let* type_ = required "type" string fields in
  let* id = required "id" string fields in
  match type_ with
  | "click" -> Ok (Click { id })
  | "change" ->
    let* value = required "value" decode_value fields in
    Ok (Change { id; value })
  | "submit" ->
    let* values = required "values" decode_values fields in
    Ok (Submit { id; values })
  | _ -> Error "unknown component event type"

let encode message =
  let fields = ("protocolVersion", `Int protocol_version) :: match message with
    | New_session -> [("type", `String "newSession")]
    | Resume_session { session_id } -> [
        ("type", `String "resumeSession");
        ("sessionId", `String session_id);
      ]
    | Component_event { session_id; event_id; base_revision; event } -> [
        ("type", `String "componentEvent");
        ("sessionId", `String session_id);
        ("eventId", `String event_id);
        ("baseRevision", `Int base_revision);
        ("event", encode_event event);
      ]
    | Cancel { session_id } -> [
        ("type", `String "cancel");
        ("sessionId", `String session_id);
      ]
  in
  `Assoc fields

let decode value =
  let* fields = object_fields value in
  let* version = required "protocolVersion" integer fields in
  if version <> protocol_version then Error "unsupported protocol version"
  else
    let* type_ = required "type" string fields in
    match type_ with
    | "newSession" -> Ok New_session
    | "resumeSession" ->
      let* session_id = required "sessionId" string fields in
      Ok (Resume_session { session_id })
    | "componentEvent" ->
      let* session_id = required "sessionId" string fields in
      let* event_id = required "eventId" string fields in
      let* base_revision = required "baseRevision" integer fields in
      let* event = required "event" decode_event fields in
      Ok (Component_event { session_id; event_id; base_revision; event })
    | "cancel" ->
      let* session_id = required "sessionId" string fields in
      Ok (Cancel { session_id })
    | _ -> Error "unknown client message type"

let encode_string message = Melange_json.to_string (encode message)

let decode_string value =
  try decode (Melange_json.of_string value)
  with Melange_json.Of_string_error error -> Error error
