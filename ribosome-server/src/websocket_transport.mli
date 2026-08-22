(* Dream WebSocket transport for Ribosome. *)

val loopback : string
val max_message_size : int

type runtime = { harness : Harness_runtime.t; ui : Ui_runtime.t }

val create : harness:Harness_runtime.t -> ui:Ui_runtime.t -> runtime
val routes : runtime -> Dream.route list
val start : ?interface_:string -> ?port:int -> runtime -> unit
