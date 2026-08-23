(* Harness WebSocket handler. *)

val max_message_size : int

val handler :
  runtime:Harness_runtime.t -> conns:Connection_table.t -> Dream.handler
