(** ribosome-server private library entry point.

    The MCP subset, harness and UI protocol codecs, session registry, Dream
    WebSocket transport, and runtime implementations are assembled here. This
    module is not part of the public API — it exists solely to make the private
    library buildable and testable. *)

module Ui_protocol : module type of Ui_protocol
module Home_template : module type of Home_template
module Connection_table : module type of Connection_table
module Harness_protocol : module type of Harness_protocol
module Jsonrpc : module type of Jsonrpc
module Mcp : module type of Mcp
module Session_registry : module type of Session_registry
module Harness_runtime : module type of Harness_runtime
module Ui_runtime : module type of Ui_runtime
module Harness_handler : module type of Harness_handler
module Ui_handler : module type of Ui_handler
module Websocket_transport : module type of Websocket_transport
module Mcp_stdio : module type of Mcp_stdio

val core_version : string
