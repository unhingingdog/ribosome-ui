(** Shared WebSocket connection table. *)

type t

val create : unit -> t
val register : t -> session_id:string -> Dream.websocket -> unit
val unregister : t -> session_id:string -> unit

val send : t -> session_id:string -> string -> unit
(** Send a message to the WebSocket registered for [session_id]. Uses
    [Lwt.async] — fire-and-forget. Drops silently if no connection. *)
