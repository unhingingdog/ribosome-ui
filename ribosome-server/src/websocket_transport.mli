(* Dream WebSocket transport for Ribosome. *)

val loopback : string
val max_message_size : int

type runtime = {
  harness : Harness_runtime.t;
  ui : Ui_runtime.t;
  ui_conns : Connection_table.t;
  harness_conns : Connection_table.t;
}

val create :
  harness:Harness_runtime.t ->
  ui:Ui_runtime.t ->
  ui_conns:Connection_table.t ->
  harness_conns:Connection_table.t ->
  runtime

val routes : runtime -> Dream.route list
val start : ?interface_:string -> ?port:int -> runtime -> unit
