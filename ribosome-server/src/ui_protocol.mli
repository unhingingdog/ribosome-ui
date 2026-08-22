(* Versioned UI protocol types. *)

val version : string

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
}

type template_update = {
  session_id : session_id;
  revision : int;
  tree : string;
}

type generation_lifecycle =
  | Started of { session_id : session_id; generation_id : string }
  | Delta of { session_id : session_id; generation_id : string; seq : int }
  | Completed of { session_id : session_id; generation_id : string }
  | Failed of { session_id : session_id; generation_id : string }

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
  | GenerationLifecycle of generation_lifecycle
  | EventRejection of event_rejection

val encode_message : message -> Yojson.Safe.t
val decode_message : Yojson.Safe.t -> (message, string) result
