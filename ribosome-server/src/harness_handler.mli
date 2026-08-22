(* Harness WebSocket handler. *)

val max_message_size : int
val handler : runtime:Harness_runtime.t -> Dream.handler
