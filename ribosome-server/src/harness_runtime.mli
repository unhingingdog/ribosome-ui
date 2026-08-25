(* Harness runtime: routes harness protocol messages into Ribosome sessions. *)

type broadcast = {
  broadcast_template_update :
    session_id:string -> revision:int -> tree:string -> unit;
}

type t
type delta_result = Updated | Pending | Corrupted
type handle_result = Attached | DeltaResult of delta_result | Completed
type rejection = Harness_protocol.rejection_reason
type error

val create : registry:Session_registry.t -> broadcast:broadcast -> t
val register_session : t -> session_id:string -> unit
val put_session : t -> session_id:string -> Ribosome.Session.t -> unit
val get_session : t -> session_id:string -> Ribosome.Session.t option

val handle_message :
  t -> Harness_protocol.message -> (handle_result, rejection) result

val handle_generation_completed :
  t -> session_id:string -> generation_id:string -> (unit, error) result
