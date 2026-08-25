import { Option } from "effect";
import type { Hooks, PluginInput, PluginOptions } from "@opencode-ai/plugin";
import type { AdapterConfig, InputEvent } from "./types.js";
import { createConfig } from "./types.js";
import { createRuntime, type Runtime, type PromptClient } from "./runtime.js";
import type { WebSocketFactory } from "./transport.js";

function toInputEvent(
  event: { type: string; properties: any },
  partTypes: Map<string, string>,
): InputEvent | null {
  if (event.type === "message.part.updated") {
    const props = event.properties;
    const part = props.part;
    if (!part) return null;
    const rawPartType = part.type ?? props.type ?? "";
    const partType = rawPartType === "" ? "text" : rawPartType;
    if (part.id) partTypes.set(part.id, partType);
    return {
      kind: "PartUpdated",
      ocId: part.sessionID ?? props.sessionID ?? "",
      messageId: part.messageID ?? props.messageID ?? "",
      partType,
      delta: props.delta ? Option.some(props.delta) : Option.none(),
    };
  }

  if (event.type === "message.part.delta") {
    const props = event.properties;
    const partID = props.partID ?? "";
    const partType = partTypes.get(partID) ?? "text";
    if (partType !== "text") return null;
    return {
      kind: "PartUpdated",
      ocId: props.sessionID ?? "",
      messageId: props.messageID ?? "",
      partType: "text",
      delta: props.delta ? Option.some(props.delta) : Option.none(),
    };
  }

  if (event.type === "session.idle") {
    return {
      kind: "SessionIdle",
      ocId: event.properties.sessionID,
    };
  }

  if (event.type === "session.error") {
    const errorStr = event.properties.error
      ? JSON.stringify(event.properties.error)
      : undefined;
    return {
      kind: "SessionError",
      ocId: event.properties.sessionID ?? "",
      error: errorStr ? Option.some(errorStr) : Option.none(),
    };
  }

  return null;
}

export function createPlugin(
  wsFactory: WebSocketFactory,
  defaultConfig?: Partial<AdapterConfig>,
): (input: PluginInput, options?: PluginOptions) => Promise<Hooks> {
  return async (input, _options) => {
    const config = createConfig(
      defaultConfig?.serverUrl ?? "ws://127.0.0.1:8787",
      defaultConfig?.mcpToolName,
    );

    const promptClient = input.client as unknown as PromptClient;
    const runtime = createRuntime(config, wsFactory, promptClient);
    const partTypes = new Map<string, string>();

    return {
      "tool.execute.before": async (toolInput, output) => {
        let nonce = "";
        if (
          toolInput.tool === config.mcpToolName ||
          toolInput.tool.endsWith("_" + config.mcpToolName)
        ) {
          if (output.args && typeof output.args === "object") {
            const args = output.args as Record<string, unknown>;
            nonce = `oc-${Math.random().toString(36).slice(2, 10)}`;
            args._nonce = nonce;
            args._harness_session_id = toolInput.sessionID;
          }
        }

        runtime.push({
          kind: "ToolBefore",
          ocId: toolInput.sessionID,
          tool: toolInput.tool,
          callId: toolInput.callID,
          nonce,
        });
      },

      "tool.execute.after": async (toolInput, toolOutput) => {
        runtime.push({
          kind: "ToolAfter",
          ocId: toolInput.sessionID,
          tool: toolInput.tool,
          callId: toolInput.callID,
          output: toolOutput.output,
        });
      },

      event: async (eventInput) => {
        const ev = toInputEvent(
          eventInput.event as { type: string; properties: any },
          partTypes,
        );
        if (ev) runtime.push(ev);
      },

      dispose: async () => {
        runtime.shutdown();
      },
    };
  };
}
