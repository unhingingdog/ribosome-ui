(* UI WebSocket handler. *)

val max_message_size : int
val handler : runtime:Ui_runtime.t -> Dream.handler
