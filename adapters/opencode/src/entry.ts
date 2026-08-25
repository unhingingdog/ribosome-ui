import { createPlugin } from "./plugin.js";
import { setLogSink, createStderrSink } from "./log.js";

setLogSink(createStderrSink());

const plugin = createPlugin(
  (url: string) => new WebSocket(url) as any,
  {
    serverUrl: process.env.RIBOSOME_SERVER_URL ?? "ws://127.0.0.1:8787",
    mcpToolName: process.env.RIBOSOME_MCP_TOOL_NAME ?? "start",
  },
);

export default plugin;
