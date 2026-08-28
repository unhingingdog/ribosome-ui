import { createPlugin } from "./plugin.js";
import { setLogSink, createStderrSink } from "./log.js";
import type { WebSocketLike } from "./transport.js";

// Logs go to stderr only when RIBOSOME_DEBUG=1 (the demo sets it on the
// `opencode serve` subprocess, redirecting stderr to .logs/opencode.log).
// Otherwise the sink stays a noop so nothing renders over the TUI.
if (process.env.RIBOSOME_DEBUG === "1") {
  setLogSink(createStderrSink());
}

const plugin = createPlugin(
  (url: string) => new WebSocket(url) as unknown as WebSocketLike,
  {
    serverUrl: process.env.RIBOSOME_SERVER_URL ?? "ws://127.0.0.1:8787",
    mcpToolName: process.env.RIBOSOME_MCP_TOOL_NAME ?? "start",
  },
);

export default plugin;
