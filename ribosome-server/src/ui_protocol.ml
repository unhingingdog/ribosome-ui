let ( let* ) = Result.bind

(* Versioned UI protocol types.

   UI clients attach over WebSocket to /v1/ui with their session nonce. On attach
   they receive the current sessionState snapshot. Each committed revision
   broadcasts a templateUpdate. Clients send componentEvent messages (click,
   change, submit) carrying event ID and base revision. change events apply
   locally and broadcast immediately; click and submit events produce one
   userTurn for the harness adapter. Stale revisions and duplicate event IDs are
   rejected. Reconnect from a known revision resends the snapshot. *)

let version = "0.0.0"

type session_id = string
type attach = { session_id : session_id; revision : int option }
type component_kind = Click | Change | Submit

type component_event = {
  session_id : session_id;
  revision : int;
  event_id : string;
  target_id : string;
  kind : component_kind;
  value : string option;
}

type cancel = { session_id : session_id }
type disconnect = { session_id : session_id }

type session_state = {
  session_id : session_id;
  mode : string;
  revision : int;
  tree : string option;
      (* JSON-encoded template; None when no tree exists yet *)
  generation_id : string option; (* active generation if any *)
}

type template_update = {
  session_id : session_id;
  revision : int;
  tree : string; (* JSON-encoded template *)
}

type event_rejection_reason = StaleRevision | DuplicateEventId

type event_rejection = {
  session_id : session_id;
  event_id : string;
  reason : event_rejection_reason;
}

type message =
  | Attach of attach
  | ComponentEvent of component_event
  | Cancel of cancel
  | Disconnect of disconnect
  | SessionState of session_state
  | TemplateUpdate of template_update
  | EventRejection of event_rejection

let component_kind_to_string = function
  | Click -> "click"
  | Change -> "change"
  | Submit -> "submit"

let component_kind_of_string = function
  | "click" -> Ok Click
  | "change" -> Ok Change
  | "submit" -> Ok Submit
  | s -> Error ("unknown component kind: " ^ s)

let rejection_reason_to_string = function
  | StaleRevision -> "stale_revision"
  | DuplicateEventId -> "duplicate_event_id"

let rejection_reason_of_string = function
  | "stale_revision" -> Ok StaleRevision
  | "duplicate_event_id" -> Ok DuplicateEventId
  | s -> Error ("unknown rejection reason: " ^ s)

let encode_message msg : Yojson.Safe.t =
  match msg with
  | Attach a ->
      `Assoc
        ([ ("kind", `String "attach"); ("session_id", `String a.session_id) ]
        @
        match a.revision with
        | None -> []
        | Some r -> [ ("revision", `Int r) ])
  | ComponentEvent e ->
      `Assoc
        ([
           ("kind", `String "component_event");
           ("session_id", `String e.session_id);
           ("revision", `Int e.revision);
           ("event_id", `String e.event_id);
           ("target_id", `String e.target_id);
           ("component_kind", `String (component_kind_to_string e.kind));
         ]
        @ match e.value with None -> [] | Some v -> [ ("value", `String v) ])
  | Cancel c ->
      `Assoc
        [ ("kind", `String "cancel"); ("session_id", `String c.session_id) ]
  | Disconnect d ->
      `Assoc
        [ ("kind", `String "disconnect"); ("session_id", `String d.session_id) ]
  | SessionState s ->
      `Assoc
        ([
           ("kind", `String "session_state");
           ("session_id", `String s.session_id);
           ("mode", `String s.mode);
           ("revision", `Int s.revision);
         ]
        @
        match s.tree with
        | None -> []
        | Some t -> (
            [ ("tree", `String t) ]
            @
            match s.generation_id with
            | None -> []
            | Some g -> [ ("generation_id", `String g) ]))
  | TemplateUpdate t ->
      `Assoc
        [
          ("kind", `String "template_update");
          ("session_id", `String t.session_id);
          ("revision", `Int t.revision);
          ("tree", `String t.tree);
        ]
  | EventRejection r ->
      `Assoc
        [
          ("kind", `String "event_rejection");
          ("session_id", `String r.session_id);
          ("event_id", `String r.event_id);
          ("reason", `String (rejection_reason_to_string r.reason));
        ]

let decode_message json : (message, string) result =
  let kind_field json =
    match json with
    | `Assoc fields -> (
        match Stdlib.List.assoc_opt "kind" fields with
        | Some (`String k) -> Ok (k, fields)
        | _ -> Error "missing or non-string 'kind' field")
    | _ -> Error "expected object"
  in
  let string_field name fields =
    match Stdlib.List.assoc_opt name fields with
    | Some (`String s) -> Ok s
    | _ -> Error ("expected string field: " ^ name)
  in
  let int_field name fields =
    match Stdlib.List.assoc_opt name fields with
    | Some (`Int n) -> Ok n
    | _ -> Error ("expected int field: " ^ name)
  in
  let* kind, fields = kind_field json in
  match kind with
  | "attach" ->
      let* session_id = string_field "session_id" fields in
      let revision =
        match Stdlib.List.assoc_opt "revision" fields with
        | Some (`Int r) -> Some r
        | _ -> None
      in
      Ok (Attach { session_id; revision })
  | "component_event" ->
      let* session_id = string_field "session_id" fields in
      let* revision = int_field "revision" fields in
      let* event_id = string_field "event_id" fields in
      let* target_id = string_field "target_id" fields in
      let* component_kind = string_field "component_kind" fields in
      let* kind = component_kind_of_string component_kind in
      let value =
        match Stdlib.List.assoc_opt "value" fields with
        | Some (`String v) -> Some v
        | _ -> None
      in
      Ok
        (ComponentEvent
           { session_id; revision; event_id; target_id; kind; value })
  | "cancel" ->
      let* session_id = string_field "session_id" fields in
      Ok (Cancel { session_id })
  | "disconnect" ->
      let* session_id = string_field "session_id" fields in
      Ok (Disconnect { session_id })
  | "session_state" ->
      let* session_id = string_field "session_id" fields in
      let* mode = string_field "mode" fields in
      let* revision = int_field "revision" fields in
      let tree =
        match Stdlib.List.assoc_opt "tree" fields with
        | Some (`String t) -> Some t
        | _ -> None
      in
      let generation_id =
        match Stdlib.List.assoc_opt "generation_id" fields with
        | Some (`String g) -> Some g
        | _ -> None
      in
      Ok (SessionState { session_id; mode; revision; tree; generation_id })
  | "template_update" ->
      let* session_id = string_field "session_id" fields in
      let* revision = int_field "revision" fields in
      let* tree = string_field "tree" fields in
      Ok (TemplateUpdate { session_id; revision; tree })
  | "event_rejection" ->
      let* session_id = string_field "session_id" fields in
      let* event_id = string_field "event_id" fields in
      let* reason_str = string_field "reason" fields in
      let* reason = rejection_reason_of_string reason_str in
      Ok (EventRejection { session_id; event_id; reason })
  | k -> Error ("unknown message kind: " ^ k)
