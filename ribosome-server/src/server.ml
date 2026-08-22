(* ribosome-server private library entry point.

   The MCP subset, harness and UI protocol codecs, session registry, and Dream
   WebSocket transport are added in later tasks. This placeholder makes the
   private library buildable and proves the dependency on [ribosome] links
   correctly. *)

module Ui_protocol = Ui_protocol
module Harness_protocol = Harness_protocol
module Jsonrpc = Jsonrpc
module Mcp = Mcp
module Session_registry = Session_registry

let core_version = Ribosome.version
