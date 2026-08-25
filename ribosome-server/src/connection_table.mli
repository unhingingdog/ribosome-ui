(** Shared WebSocket connection table.

    Maps session_id → Dream.websocket so broadcast callbacks can send
    directly via Lwt.async without a queue. Supports a "pending"
    WebSocket as fallback for messages sent before explicit session
    registration (e.g. user_turn delivered before Attach). *)

type t = {
  connections : (string, Dream.websocket) Hashtbl.t;
  mutable pending : Dream.websocket option;
}

val create : unit -> t

val register : t -> session_id:string -> Dream.websocket -> unit
(** Register a WebSocket for a session. Replaces any prior entry. *)

val unregister : t -> session_id:string -> unit
(** Remove the registered WebSocket for [session_id]. Does not affect pending. *)

val set_pending : t -> Dream.websocket -> unit
(** Set a fallback WebSocket used when [send] finds no session_keyed connection. *)

val clear_pending : t -> unit
(** Clear the pending fallback WebSocket. *)

val send : t -> session_id:string -> string -> unit
(** Send a message to the WebSocket registered for [session_id]. If none is
    registered, falls back to the pending WebSocket. Uses [Lwt.async] —
    fire-and-forget. Drops silently if no connection and no pending. *)
