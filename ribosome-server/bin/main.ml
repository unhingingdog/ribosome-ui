(* ribosome-server executable entry point.

   Cmdliner options, MCP stdio processing, and Dream WebSocket routes are
   wired up in later tasks. This placeholder lets the native executable build
   and link against the private server library. *)

let () =
  print_endline ("ribosome-server " ^ Ribosome_server_lib.Server.core_version)
