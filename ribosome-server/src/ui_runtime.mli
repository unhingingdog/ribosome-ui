(* UI runtime: routes UI protocol messages into Ribosome sessions. *)

type ui_broadcast = {
  broadcast_template_update :
    session_id:string -> revision:int -> tree:string -> unit;
  broadcast_session_state :
    session_id:string ->
    mode:string ->
    revision:int ->
    tree:string option ->
    generation_id:string option ->
    unit;
  broadcast_event_rejection :
    session_id:string ->
    event_id:string ->
    reason:Ui_protocol.event_rejection_reason ->
    unit;
  send_user_turn : session_id:string -> tree:string -> event:string -> unit;
}

type t

type error =
  | InvalidSession
  | InvalidNonce
  | NoActiveSession
  | EventError of string

val create : registry:Session_registry.t -> broadcast:ui_broadcast -> t
val register_session : t -> session_id:string -> unit
val put_session : t -> session_id:string -> Ribosome.Session.t -> unit
val get_session : t -> session_id:string -> Ribosome.Session.t option
val handle_message : t -> Ui_protocol.message -> (unit, error) result
val error_string : error -> string
