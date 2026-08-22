(* Session registry. *)

type conn_id = string
type ui_conn = { conn_id : conn_id; revision : int }
type harness_conn = { conn_id : conn_id }

type entry = {
  session_id : string;
  mode : string;
  harness_session_id : string;
  harness_nonce : string;
  ui_nonce : string;
  mutable ui_connections : ui_conn list;
  mutable harness_connection : harness_conn option;
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

val attach_ui :
  t ->
  string ->
  conn_id:conn_id ->
  revision:int ->
  (unit, [> `NotFound ]) result

val detach_ui : t -> string -> conn_id:conn_id -> (unit, [> `NotFound ]) result

val attach_harness :
  t -> string -> conn_id:conn_id -> (unit, [> `NotFound ]) result

val detach_harness : t -> string -> (unit, [> `NotFound ]) result

val reconnect_ui :
  t ->
  string ->
  conn_id:conn_id ->
  revision:int ->
  (unit, [> `NotFound ]) result

val ui_connections : t -> string -> ui_conn list
val harness_connection : t -> string -> harness_conn option
