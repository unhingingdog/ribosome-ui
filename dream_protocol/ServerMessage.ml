type t =
  | Session_state of {
      session_id: string;
      revision: int;
      tree: Ribosome_core.Types.template option;
    }
  | Template_update of {
      session_id: string;
      revision: int;
      tree: Ribosome_core.Types.template;
    }
  | Generation_started of {
      session_id: string;
      turn_id: string;
    }
  | Generation_completed of {
      session_id: string;
      turn_id: string;
    }
  | Generation_failed of {
      session_id: string;
      turn_id: string;
      message: string;
    }
  | Event_rejected of {
      session_id: string;
      event_id: string;
      reason: string;
    }

type error = string

let protocol_version = ClientMessage.protocol_version
let ( let* ) = Result.bind

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

let encode_tree tree = Ribosome_native_codec.TemplateCodec.encode_template tree

let decode_tree value =
  Result.map_error (fun error -> "invalid template: " ^ error)
    (Ribosome_native_codec.TemplateCodec.decode_template value)

let with_header type_ fields =
  `Assoc (("protocolVersion", `Int protocol_version) :: ("type", `String type_) :: fields)

let encode = function
  | Session_state { session_id; revision; tree } ->
    let fields = [
      ("sessionId", `String session_id);
      ("revision", `Int revision);
    ] in
    (match tree with
     | Some tree -> with_header "sessionState" (fields @ [("tree", encode_tree tree)])
     | None -> with_header "sessionState" fields)
  | Template_update { session_id; revision; tree } -> with_header "templateUpdate" [
      ("sessionId", `String session_id);
      ("revision", `Int revision);
      ("tree", encode_tree tree);
    ]
  | Generation_started { session_id; turn_id } -> with_header "generationStarted" [
      ("sessionId", `String session_id);
      ("turnId", `String turn_id);
    ]
  | Generation_completed { session_id; turn_id } -> with_header "generationCompleted" [
      ("sessionId", `String session_id);
      ("turnId", `String turn_id);
    ]
  | Generation_failed { session_id; turn_id; message } -> with_header "generationFailed" [
      ("sessionId", `String session_id);
      ("turnId", `String turn_id);
      ("message", `String message);
    ]
  | Event_rejected { session_id; event_id; reason } -> with_header "eventRejected" [
      ("sessionId", `String session_id);
      ("eventId", `String event_id);
      ("reason", `String reason);
    ]

let decode_session_state fields =
  let* session_id = required "sessionId" string fields in
  let* revision = required "revision" integer fields in
  let* tree = match Stdlib.List.assoc_opt "tree" fields with
    | Some tree -> Result.map Option.some (decode_tree tree)
    | None -> Ok None
  in
  Ok (Session_state { session_id; revision; tree })

let decode_template_update fields =
  let* session_id = required "sessionId" string fields in
  let* revision = required "revision" integer fields in
  let* tree = required "tree" decode_tree fields in
  Ok (Template_update { session_id; revision; tree })

let decode_generation constructor fields =
  let* session_id = required "sessionId" string fields in
  let* turn_id = required "turnId" string fields in
  Ok (constructor session_id turn_id)

let decode fields =
  let* version = required "protocolVersion" integer fields in
  if version <> protocol_version then Error "unsupported protocol version"
  else
    let* type_ = required "type" string fields in
    match type_ with
    | "sessionState" -> decode_session_state fields
    | "templateUpdate" -> decode_template_update fields
    | "generationStarted" ->
      decode_generation (fun session_id turn_id -> Generation_started { session_id; turn_id }) fields
    | "generationCompleted" ->
      decode_generation (fun session_id turn_id -> Generation_completed { session_id; turn_id }) fields
    | "generationFailed" ->
      let* session_id = required "sessionId" string fields in
      let* turn_id = required "turnId" string fields in
      let* message = required "message" string fields in
      Ok (Generation_failed { session_id; turn_id; message })
    | "eventRejected" ->
      let* session_id = required "sessionId" string fields in
      let* event_id = required "eventId" string fields in
      let* reason = required "reason" string fields in
      Ok (Event_rejected { session_id; event_id; reason })
    | _ -> Error "unknown server message type"

let encode_string message = Melange_json.to_string (encode message)

let decode_string value =
  try
    let* fields = object_fields (Melange_json.of_string value) in
    decode fields
  with Melange_json.Of_string_error error -> Error error
