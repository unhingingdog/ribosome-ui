(* Minimal session registry. *)

type entry = {
  session_id : string;
  mode : string;
  harness_session_id : string;
  harness_nonce : string;
  ui_nonce : string;
}

type t
type id_gen = { gen_session_id : unit -> string; gen_ui_nonce : unit -> string }

val create : unit -> t
val find : t -> string -> entry option
val find_by_harness : t -> string -> entry option

val start :
  ?mode:string ->
  id_gen:id_gen ->
  registry:t ->
  harness_session_id:string ->
  harness_nonce:string ->
  unit ->
  (entry, [> `Duplicate ]) result
