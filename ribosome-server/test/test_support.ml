(* Shared helpers for readable ribosome-server test assertions.

   The server currently exposes only [core_version]; the MCP subset, harness
   and UI protocol codecs, and session registry land in Feature 5. This
   module keeps a placeholder Lwt helper used by the smoke test to prove
   the Alcotest-Lwt runner wires up. *)

let core_version_is_set () : bool =
  String.length Ribosome_server_lib.Server.core_version > 0
