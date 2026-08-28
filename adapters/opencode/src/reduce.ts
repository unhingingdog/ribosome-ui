import { Option } from "effect";
import type {
  AdapterConfig,
  Effect,
  HarnessOutbound,
  InputEvent,
  SessionState,
  SessionStore,
  StreamingPhase,
  Transition,
  UserTurn,
} from "./types.js";
import {
  findSessionByRibId,
  isStartTool,
  makeSession,
  putSession,
  removeSession,
  SessionPhase,
  updateStore,
} from "./types.js";
import { formatPrompt } from "./skills.js";

interface StartResult {
  readonly session_id: string;
  readonly ui_nonce: string;
}

function noEffects(store: SessionStore): Transition {
  return { store, effects: [] };
}

function effects(store: SessionStore, ...effs: Effect[]): Transition {
  return { store, effects: effs };
}

function generateMessageId(): string {
  return `msg-ribo-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function isStartResult(value: unknown): value is StartResult {
  if (typeof value !== "object" || value === null) return false;
  const rec = value as Record<string, unknown>;
  return typeof rec.session_id === "string" && typeof rec.ui_nonce === "string";
}

// The start tool returns a JSON blob; output may not be JSON at all.
// opencode passes MCP tool results to tool.execute.after as the raw
// CallToolResult ({content, structuredContent, isError}), so the parsed
// value may already be an object.
function parseStartResult(output: unknown): Option.Option<StartResult> {
  const parsed: unknown =
    typeof output === "object" && output !== null
      ? output
      : (() => {
          try {
            return JSON.parse(String(output));
          } catch {
            return undefined;
          }
        })();
  return isStartResult(parsed) ? Option.some(parsed) : Option.none();
}

function scanForJsonStart(prefix: string): { found: boolean; content: string } {
  const idx = prefix.search(/[{[]/);
  if (idx === -1) return { found: false, content: "" };
  return { found: true, content: prefix.slice(idx) };
}

function startStreaming(messageId: string): StreamingPhase {
  return {
    _tag: "Streaming",
    genId: messageId,
    seq: 0,
    jsonStarted: false,
    buffer: "",
    pendingPrefix: "",
  };
}

function kickoff(state: SessionState, callId: string, nonce: Option.Option<string>): SessionState {
  return { ...state, phase: SessionPhase.KickoffPending(callId), nonce };
}

function reduceToolBefore(
  store: SessionStore,
  ev: Extract<InputEvent, { kind: "ToolBefore" }>,
  config: AdapterConfig,
): Transition {
  if (!isStartTool(ev.tool, config)) return noEffects(store);
  const base = store.sessions.get(ev.ocId) ?? makeSession(ev.ocId);
  return noEffects(putSession(store, kickoff(base, ev.callId, ev.nonce)));
}

function resetToIdle(store: SessionStore, ocId: string): SessionStore {
  return updateStore(store, ocId, (s) => ({ ...s, phase: SessionPhase.Idle() }));
}

function attachSession(
  store: SessionStore,
  state: SessionState,
  ocId: string,
  result: StartResult,
): Transition {
  const updated = updateStore(store, ocId, (s) => ({
    ...s,
    ribId: Option.some(result.session_id),
    phase: startStreaming(""),
  }));
  return effects(updated, {
    kind: "SendHarness",
    msg: {
      kind: "attach",
      session_id: result.session_id,
      harness_session_id: ocId,
      nonce: Option.getOrElse(state.nonce, () => ""),
    },
  });
}

function reduceToolAfter(
  store: SessionStore,
  ev: Extract<InputEvent, { kind: "ToolAfter" }>,
  config: AdapterConfig,
): Transition {
  if (!isStartTool(ev.tool, config)) return noEffects(store);

  const state = store.sessions.get(ev.ocId);
  if (!state || state.phase._tag !== "KickoffPending") return noEffects(store);

  return Option.match(parseStartResult(ev.output), {
    onNone: () => noEffects(resetToIdle(store, ev.ocId)),
    onSome: (result) => attachSession(store, state, ev.ocId, result),
  });
}

function streamFields(phase: SessionPhase, messageId: string): Option.Option<StreamingPhase> {
  switch (phase._tag) {
    case "Idle":
    case "AwaitingTurn":
    case "KickoffPending":
      return Option.some(startStreaming(messageId));
    case "Streaming":
      return Option.some(phase.genId === "" ? { ...phase, genId: messageId } : phase);
    case "Completing":
      return Option.none();
  }
}

function appendDelta(fields: StreamingPhase, delta: string): StreamingPhase {
  if (fields.jsonStarted) {
    return { ...fields, buffer: fields.buffer + delta };
  }
  const combined = fields.pendingPrefix + delta;
  const scan = scanForJsonStart(combined);
  if (!scan.found) {
    return { ...fields, pendingPrefix: combined };
  }
  return {
    ...fields,
    jsonStarted: true,
    buffer: fields.buffer + scan.content,
    pendingPrefix: "",
  };
}

function reducePartUpdated(
  store: SessionStore,
  ev: Extract<InputEvent, { kind: "PartUpdated" }>,
): Transition {
  const state = store.sessions.get(ev.ocId);
  if (!state) return noEffects(store);

  if (state.injectedMessageIds.has(ev.messageId)) return noEffects(store);
  if (ev.partType !== "text") return noEffects(store);
  if (Option.isNone(state.ribId)) return noEffects(store);

  const flow = Option.zipWith(
    Option.filter(ev.delta, (delta) => delta !== ""),
    streamFields(state.phase, ev.messageId),
    (delta, fields) => ({ delta, fields }),
  );

  return Option.match(flow, {
    onNone: () => noEffects(store),
    onSome: ({ delta, fields }) => {
      const phase = appendDelta(fields, delta);
      return noEffects(updateStore(store, ev.ocId, (s) => ({ ...s, phase })));
    },
  });
}

function deltaFrame(ribId: string, phase: StreamingPhase): HarnessOutbound {
  return {
    kind: "delta",
    session_id: ribId,
    generation_id: phase.genId,
    seq: phase.seq,
    content: phase.buffer,
  };
}

function consumeBuffer(phase: StreamingPhase): StreamingPhase {
  return { ...phase, seq: phase.seq + 1, buffer: "", pendingPrefix: "" };
}

function reduceFlushBatch(store: SessionStore, ocId: string): Transition {
  const state = store.sessions.get(ocId);
  if (!state) return noEffects(store);

  const phase = state.phase;
  if (phase._tag !== "Streaming" || phase.buffer.length === 0) return noEffects(store);

  return Option.match(state.ribId, {
    onNone: () => noEffects(store),
    onSome: (ribId) => {
      const updated = updateStore(store, ocId, (s) => ({ ...s, phase: consumeBuffer(phase) }));
      return effects(updated, { kind: "SendHarness", msg: deltaFrame(ribId, phase) });
    },
  });
}

function completionFrames(ribId: string, phase: SessionPhase): ReadonlyArray<HarnessOutbound> {
  if (phase._tag !== "Streaming") return [];
  const frames: HarnessOutbound[] = [];
  if (phase.buffer.length > 0) {
    frames.push(deltaFrame(ribId, phase));
  }
  frames.push({
    kind: "generation_completed",
    session_id: ribId,
    generation_id: phase.genId,
  });
  return frames;
}

function settleQueuedTurn(
  store: SessionStore,
  state: SessionState,
): { store: SessionStore; effects: Effect[] } {
  return Option.match(state.queuedTurn, {
    onNone: () => ({
      store: updateStore(store, state.ocId, (s) => ({ ...s, phase: SessionPhase.AwaitingTurn() })),
      effects: [],
    }),
    onSome: (turn) => {
      const messageId = generateMessageId();
      const text = formatPrompt(turn.tree, turn.event);
      return {
        store: updateStore(store, state.ocId, (s) => ({
          ...s,
          phase: startStreaming(""),
          queuedTurn: Option.none(),
          injectedMessageIds: new Set([...s.injectedMessageIds, messageId]),
        })),
        effects: [{ kind: "InjectPrompt", ocId: state.ocId, text, messageId }],
      };
    },
  });
}

function reduceSessionIdle(
  store: SessionStore,
  ev: Extract<InputEvent, { kind: "SessionIdle" }>,
): Transition {
  const state = store.sessions.get(ev.ocId);
  if (!state) return noEffects(store);

  const phase = state.phase;
  if (phase._tag !== "Streaming" && phase._tag !== "Completing") return noEffects(store);

  return Option.match(state.ribId, {
    onNone: () => noEffects(store),
    onSome: (ribId) => {
      const turn = settleQueuedTurn(store, state);
      return effects(
        turn.store,
        ...completionFrames(ribId, phase).map((msg) => ({ kind: "SendHarness" as const, msg })),
        ...turn.effects,
      );
    },
  });
}

function reduceSessionError(
  store: SessionStore,
  ev: Extract<InputEvent, { kind: "SessionError" }>,
): Transition {
  const state = store.sessions.get(ev.ocId);
  if (!state) return noEffects(store);

  const phase = state.phase;
  if (phase._tag !== "Streaming") return noEffects(removeSession(store, ev.ocId));

  return Option.match(state.ribId, {
    onNone: () => noEffects(removeSession(store, ev.ocId)),
    onSome: (ribId) =>
      effects(removeSession(store, ev.ocId), {
        kind: "SendHarness",
        msg: {
          kind: "generation_failed",
          session_id: ribId,
          generation_id: phase.genId,
          reason: Option.getOrNull(ev.error),
        },
      }),
  });
}

function routeTurn(store: SessionStore, session: SessionState, turn: UserTurn): Transition {
  const phase = session.phase;

  if (phase._tag === "Streaming" || phase._tag === "Completing") {
    if (Option.isSome(session.queuedTurn)) return noEffects(store);
    return noEffects(updateStore(store, session.ocId, (s) => ({ ...s, queuedTurn: Option.some(turn) })));
  }

  if (phase._tag === "Idle" || phase._tag === "AwaitingTurn") {
    const messageId = generateMessageId();
    const text = formatPrompt(turn.tree, turn.event);
    const streaming = updateStore(store, session.ocId, (s) => ({
      ...s,
      phase: startStreaming(""),
      injectedMessageIds: new Set([...s.injectedMessageIds, messageId]),
    }));
    return effects(streaming, { kind: "InjectPrompt", ocId: session.ocId, text, messageId });
  }

  return noEffects(store);
}

function reduceUserTurnRecv(
  store: SessionStore,
  ev: Extract<InputEvent, { kind: "UserTurnRecv" }>,
): Transition {
  const turn: UserTurn = { sessionId: ev.ribId, tree: ev.tree, event: ev.event };

  return Option.match(findSessionByRibId(store, ev.ribId), {
    onNone: () => {
      const pendingTurns = new Map(store.pendingUiTurns);
      pendingTurns.set(ev.ribId, turn);
      return effects(
        { ...store, pendingUiTurns: pendingTurns },
        { kind: "CreateOcSession", ribId: ev.ribId },
      );
    },
    onSome: (session) => routeTurn(store, session, turn),
  });
}

function reduceOcSessionCreated(
  store: SessionStore,
  ev: Extract<InputEvent, { kind: "OcSessionCreated" }>,
): Transition {
  const pendingTurns = new Map(store.pendingUiTurns);
  pendingTurns.delete(ev.ribId);

  const inject = Option.map(Option.fromNullable(store.pendingUiTurns.get(ev.ribId)), (turn) => {
    const messageId = generateMessageId();
    return { messageId, text: formatPrompt(turn.tree, turn.event) };
  });

  const state: SessionState = {
    ...makeSession(ev.ocId),
    ribId: Option.some(ev.ribId),
    phase: startStreaming(""),
    queuedTurn: Option.none(),
    injectedMessageIds: new Set(
      Option.match(inject, {
        onNone: () => [],
        onSome: (i) => [i.messageId],
      }),
    ),
  };

  const effs: Effect[] = [
    {
      kind: "SendHarness",
      msg: {
        kind: "attach",
        session_id: ev.ribId,
        harness_session_id: ev.ribId,
        nonce: "pending",
      },
    },
    ...Option.toArray(inject).map((i) => ({
      kind: "InjectPrompt" as const,
      ocId: ev.ocId,
      text: i.text,
      messageId: i.messageId,
    })),
  ];

  return effects({ ...putSession(store, state), pendingUiTurns: pendingTurns }, ...effs);
}

function reduceWsOpen(store: SessionStore): Transition {
  return noEffects(store);
}

function reduceWsClosed(store: SessionStore): Transition {
  return noEffects(store);
}

export function reduce(store: SessionStore, event: InputEvent, config: AdapterConfig): Transition {
  switch (event.kind) {
    case "ToolBefore":
      return reduceToolBefore(store, event, config);
    case "ToolAfter":
      return reduceToolAfter(store, event, config);
    case "PartUpdated":
      return reducePartUpdated(store, event);
    case "FlushBatch":
      return reduceFlushBatch(store, event.ocId);
    case "SessionIdle":
      return reduceSessionIdle(store, event);
    case "SessionError":
      return reduceSessionError(store, event);
    case "UserTurnRecv":
      return reduceUserTurnRecv(store, event);
    case "OcSessionCreated":
      return reduceOcSessionCreated(store, event);
    case "WsOpen":
      return reduceWsOpen(store);
    case "WsClosed":
      return reduceWsClosed(store);
    default:
      return noEffects(store);
  }
}