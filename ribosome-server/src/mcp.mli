(* Minimal MCP lifecycle handler. *)

val protocol_version : string

type state = Uninitialized | Initialized

val handle : state -> Jsonrpc.message -> state * Jsonrpc.message option
