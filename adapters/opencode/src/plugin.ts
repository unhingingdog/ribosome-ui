import { Option } from "effect";
import type { Hooks, PluginInput, PluginOptions } from "@opencode-ai/plugin";
import type { Event, Part } from "@opencode-ai/sdk";
import type { AdapterConfig, InputEvent } from "./types.js";
import { createConfig, generateNonce, isStartTool } from "./types.js";
import { createRuntime, type Runtime, type PromptClient } from "./runtime.js";
import type { WebSocketFactory } from "./transport.js";

export interface PartDeltaEvent {
  type: "message.part.delta";
  properties: {
    sessionID: string;
    messageID: string;
    partID: string;
    field: string;
    delta?: string;
  };
}

export type SourceEvent = Event | PartDeltaEvent;

export type PartTypeIndex = ReadonlyMap<string, string>;

function toPartUpdated(
  ocId: string,
  messageId: string,
  partType: string,
  delta?: string,
): InputEvent {
  return {
    kind: "PartUpdated",
    ocId,
    messageId,
    partType,
    delta: Option.fromNullable(delta),
  };
}

function recordPartType(index: PartTypeIndex, part: Part): PartTypeIndex {
  const next = new Map(index);
  next.set(part.id, part.type);
  return next;
}

function fromPartUpdated(
  updated: Extract<Event, { type: "message.part.updated" }>,
): InputEvent {
  const { part, delta } = updated.properties;
  return toPartUpdated(part.sessionID, part.messageID, part.type, delta);
}

// Delta events carry only a partID, so the part's type is inferred from the
// index recorded by preceding `message.part.updated` events.
function fromPartDelta(
  deltaEvent: PartDeltaEvent,
  index: PartTypeIndex,
): Option.Option<InputEvent> {
  const { sessionID, messageID, partID, delta } = deltaEvent.properties;
  const partType = index.get(partID) ?? "text";
  return partType === "text"
    ? Option.some(toPartUpdated(sessionID, messageID, "text", delta))
    : Option.none();
}

function fromSessionIdle(
  idle: Extract<Event, { type: "session.idle" }>,
): InputEvent {
  return { kind: "SessionIdle", ocId: idle.properties.sessionID };
}

function fromSessionError(
  error: Extract<Event, { type: "session.error" }>,
): InputEvent {
  const { sessionID, error: cause } = error.properties;
  return {
    kind: "SessionError",
    ocId: sessionID ?? "",
    error: Option.fromNullable(cause ? JSON.stringify(cause) : undefined),
  };
}

export function toInputEvent(
  event: SourceEvent,
  partTypes: PartTypeIndex,
): { event: Option.Option<InputEvent>; partTypes: PartTypeIndex } {
  switch (event.type) {
    case "message.part.updated":
      return {
        event: Option.some(fromPartUpdated(event)),
        partTypes: recordPartType(partTypes, event.properties.part),
      };
    case "message.part.delta":
      return { event: fromPartDelta(event, partTypes), partTypes };
    case "session.idle":
      return { event: Option.some(fromSessionIdle(event)), partTypes };
    case "session.error":
      return { event: Option.some(fromSessionError(event)), partTypes };
    default:
      return { event: Option.none(), partTypes };
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

export function injectNonce(
  toolName: string,
  sessionID: string,
  args: unknown,
  config: AdapterConfig,
): Option.Option<string> {
  if (!isStartTool(toolName, config)) return Option.none();
  if (!isRecord(args)) return Option.none();
  const nonce = generateNonce();
  args._nonce = nonce;
  args._harness_session_id = sessionID;
  return Option.some(nonce);
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
    let partTypes: PartTypeIndex = new Map<string, string>();

    return {
      "tool.execute.before": async (toolInput, output) => {
        const nonce = injectNonce(
          toolInput.tool,
          toolInput.sessionID,
          output.args,
          config,
        );
        runtime.push({
          kind: "ToolBefore",
          ocId: toolInput.sessionID,
          tool: toolInput.tool,
          callId: toolInput.callID,
          nonce,
        });
      },

      "tool.execute.after": async (toolInput, toolOutput) => {
        const raw = toolOutput as unknown as {
          content?: unknown;
          structuredContent?: unknown;
          output?: unknown;
        };
        runtime.push({
          kind: "ToolAfter",
          ocId: toolInput.sessionID,
          tool: toolInput.tool,
          callId: toolInput.callID,
          output: raw.structuredContent ?? raw.output,
        });
      },

      event: async (eventInput) => {
        const translated = toInputEvent(eventInput.event, partTypes);
        partTypes = translated.partTypes;
        Option.match(translated.event, {
          onNone: () => undefined,
          onSome: (ev) => runtime.push(ev),
        });
      },

      dispose: async () => {
        runtime.shutdown();
      },
    };
  };
}