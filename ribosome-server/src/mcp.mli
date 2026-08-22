(* Minimal MCP lifecycle handler. *)

val protocol_version : string

type config = {
  registry : Session_registry.t;
  id_gen : Session_registry.id_gen;
  skill_loader : string -> string option;
}

type state = Uninitialized | Initialized

val handle :
  config -> state -> Jsonrpc.message -> state * Jsonrpc.message option
