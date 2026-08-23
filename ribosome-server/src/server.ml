(* ribosome-server private library entry point.

   The MCP subset, harness and UI protocol codecs, session registry, and Dream
   WebSocket transport are added in later tasks. This placeholder makes the
   private library buildable and proves the dependency on [ribosome] links
   correctly. *)

[@@@warning "-60"]

module Debug = Debug

[@@@warning "+60"]

module Message_queue = Message_queue
module Home_template = Home_template
module Ui_protocol = Ui_protocol
module Harness_protocol = Harness_protocol
module Jsonrpc = Jsonrpc
module Mcp = Mcp
module Session_registry = Session_registry
module Harness_runtime = Harness_runtime
module Ui_runtime = Ui_runtime
module Harness_handler = Harness_handler
module Ui_handler = Ui_handler
module Websocket_transport = Websocket_transport
module Mcp_stdio = Mcp_stdio

let core_version = Ribosome.version
