import { Option } from "effect";
import type {
  AdapterConfig,
  Effect,
  InputEvent,
  SessionState,
  SessionStore,
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

function noEffects(store: SessionStore): Transition {
  return { store, effects: [] };
}

function effects(store: SessionStore, ...effs: Effect[]): Transition {
  return { store, effects: effs };
}

function parseStartResult(
  output: string,
): { session_id: string; ui_nonce: string } | null {
  try {
    const parsed = JSON.parse(output);
    if (
      parsed &&
      typeof parsed.session_id === "string" &&
      typeof parsed.ui_nonce === "string"
    ) {
      return { session_id: parsed.session_id, ui_nonce: parsed.ui_nonce };
    }
  } catch {
    // output may not be JSON
  }
  return null;
}

function scanForJsonStart(
  prefix: string,
): { found: boolean; content: string } {
  const idx = prefix.search(/[{[]/);
  if (idx === -1) return { found: false, content: "" };
  return { found: true, content: prefix.slice(idx) };
}

function reduceToolBefore(
  store: SessionStore,
  ev: Extract<InputEvent, { kind: "ToolBefore" }>,
  config: AdapterConfig,
): Transition {
  if (!isStartTool(ev.tool, config)) return noEffects(store);

  const existing = store.sessions.get(ev.ocId);

  const state: SessionState = existing
    ? { ...existing, phase: SessionPhase.KickoffPending(ev.callId), nonce: Option.some(ev.nonce) }
    : {
        ...makeSession(ev.ocId),
        phase: SessionPhase.KickoffPending(ev.callId),
        nonce: Option.some(ev.nonce),
      };

  return noEffects(putSession(store, state));
}

function reduceToolAfter(
  store: SessionStore,
  ev: Extract<InputEvent, { kind: "ToolAfter" }>,
  config: AdapterConfig,
): Transition {
  if (!isStartTool(ev.tool, config)) return noEffects(store);

  const state = store.sessions.get(ev.ocId);
  if (!state || state.phase._tag !== "KickoffPending") {
    return noEffects(store);
  }

  const result = parseStartResult(ev.output);
  if (!result) {
    const cleared = updateStore(store, ev.ocId, (s) => ({
      ...s,
      phase: SessionPhase.Idle(),
    }));
    return noEffects(cleared);
  }

  const harnessNonce = Option.getOrNull(state.nonce) ?? "";

  const updated = updateStore(store, ev.ocId, (s) => ({
    ...s,
    ribId: Option.some(result.session_id),
    phase: SessionPhase.Streaming("", 0, false, "", ""),
  }));

  return effects(updated, {
    kind: "SendHarness",
    msg: {
      kind: "attach",
      session_id: result.session_id,
      harness_session_id: ev.ocId,
      nonce: harnessNonce,
    },
  });
}

function reducePartUpdated(
  store: SessionStore,
  ev: Extract<InputEvent, { kind: "PartUpdated" }>,
): Transition {
  const state = store.sessions.get(ev.ocId);
  if (!state) return noEffects(store);

  if (state.injectedMessageIds.has(ev.messageId)) {
    return noEffects(store);
  }

  if (ev.partType !== "text") return noEffects(store);

  const deltaStr = Option.getOrNull(ev.delta);
  if (!deltaStr) return noEffects(store);

  const ribId = Option.getOrNull(state.ribId);
  if (!ribId) return noEffects(store);

  let phase = state.phase;

  if (phase._tag === "Idle" || phase._tag === "AwaitingTurn" || phase._tag === "KickoffPending") {
    phase = SessionPhase.Streaming(ev.messageId, 0, false, "", "");
  }

  if (phase._tag !== "Streaming") return noEffects(store);

  let { genId, seq, jsonStarted, buffer, pendingPrefix } = phase;

  if (genId === "") {
    genId = ev.messageId;
  }
  let content = deltaStr;

  if (!jsonStarted) {
    pendingPrefix += deltaStr;
    const scan = scanForJsonStart(pendingPrefix);
    if (!scan.found) {
      const updated = updateStore(store, ev.ocId, (s) => ({
        ...s,
        phase: SessionPhase.Streaming(genId, seq, false, "", pendingPrefix),
      }));
      return noEffects(updated);
    }
    jsonStarted = true;
    content = scan.content;
    pendingPrefix = "";
  }

  buffer += content;

  const updated = updateStore(store, ev.ocId, (s) => ({
    ...s,
    phase: SessionPhase.Streaming(genId, seq, jsonStarted, buffer, pendingPrefix),
  }));

  return noEffects(updated);
}

function reduceFlushBatch(
  store: SessionStore,
  ocId: string,
): Transition {
  const state = store.sessions.get(ocId);
  if (!state) return noEffects(store);

  const phase = state.phase;
  if (phase._tag !== "Streaming") return noEffects(store);
  if (phase.buffer.length === 0) return noEffects(store);

  const ribId = Option.getOrNull(state.ribId);
  if (!ribId) return noEffects(store);

  const msg = {
    kind: "delta" as const,
    session_id: ribId,
    generation_id: phase.genId,
    seq: phase.seq,
    content: phase.buffer,
  };

  const updated = updateStore(store, ocId, (s) => ({
    ...s,
    phase: SessionPhase.Streaming(
      phase.genId,
      phase.seq + 1,
      phase.jsonStarted,
      "",
      "",
    ),
  }));

  return effects(updated, { kind: "SendHarness", msg });
}

function reduceSessionIdle(
  store: SessionStore,
  ev: Extract<InputEvent, { kind: "SessionIdle" }>,
): Transition {
  const state = store.sessions.get(ev.ocId);
  if (!state) return noEffects(store);

  const ribId = Option.getOrNull(state.ribId);
  if (!ribId) return noEffects(store);

  const phase = state.phase;
  const effs: Effect[] = [];

  let nextStore = store;

  if (phase._tag === "Streaming") {
    if (phase.buffer.length > 0) {
      effs.push({
        kind: "SendHarness",
        msg: {
          kind: "delta",
          session_id: ribId,
          generation_id: phase.genId,
          seq: phase.seq,
          content: phase.buffer,
        },
      });
    }
    effs.push({
      kind: "SendHarness",
      msg: {
        kind: "generation_completed",
        session_id: ribId,
        generation_id: phase.genId,
      },
    });
  } else if (phase._tag !== "Completing") {
    return noEffects(store);
  }

  const queuedTurn = Option.getOrNull(state.queuedTurn);

  if (queuedTurn) {
    const messageId = `msg-ribo-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const injected = new Set(state.injectedMessageIds);
    injected.add(messageId);
    nextStore = updateStore(store, ev.ocId, (s) => ({
      ...s,
      phase: SessionPhase.Streaming("", 0, false, "", ""),
      queuedTurn: Option.none(),
      injectedMessageIds: injected,
    }));
    const text = formatPrompt(queuedTurn.tree, queuedTurn.event);
    effs.push({ kind: "InjectPrompt", ocId: ev.ocId, text, messageId });
  } else {
    nextStore = updateStore(store, ev.ocId, (s) => ({
      ...s,
      phase: SessionPhase.AwaitingTurn(),
    }));
  }

  return effects(nextStore, ...effs);
}

function reduceSessionError(
  store: SessionStore,
  ev: Extract<InputEvent, { kind: "SessionError" }>,
): Transition {
  const state = store.sessions.get(ev.ocId);
  if (!state) return noEffects(store);

  const ribId = Option.getOrNull(state.ribId);
  const phase = state.phase;

  if (phase._tag === "Streaming" && ribId) {
    const reason = Option.getOrNull(ev.error) ?? null;
    const cleared = removeSession(store, ev.ocId);
    return effects(cleared, {
      kind: "SendHarness",
      msg: {
        kind: "generation_failed",
        session_id: ribId,
        generation_id: phase.genId,
        reason,
      },
    });
  }

  return noEffects(removeSession(store, ev.ocId));
}

function reduceUserTurnRecv(
  store: SessionStore,
  ev: Extract<InputEvent, { kind: "UserTurnRecv" }>,
): Transition {
  const existing = findSessionByRibId(store, ev.ribId);

  const turn: UserTurn = {
    sessionId: ev.ribId,
    tree: ev.tree,
    event: ev.event,
  };

  if (!existing) {
    const pendingTurns = new Map(store.pendingUiTurns);
    pendingTurns.set(ev.ribId, turn);
    const nextStore = { ...store, pendingUiTurns: pendingTurns };
    return effects(nextStore, { kind: "CreateOcSession", ribId: ev.ribId });
  }

  const phase = existing.phase;

  if (
    phase._tag === "Streaming" ||
    phase._tag === "Completing"
  ) {
    if (Option.isSome(existing.queuedTurn)) return noEffects(store);

    const queued = updateStore(store, existing.ocId, (s) => ({
      ...s,
      queuedTurn: Option.some(turn),
    }));
    return noEffects(queued);
  }

  if (phase._tag === "Idle" || phase._tag === "AwaitingTurn") {
    const text = formatPrompt(ev.tree, ev.event);
    const messageId = `msg-ribo-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

    const injected = new Set(existing.injectedMessageIds);
    injected.add(messageId);

    const streaming = updateStore(store, existing.ocId, (s) => ({
      ...s,
      phase: SessionPhase.Streaming("", 0, false, "", ""),
      injectedMessageIds: injected,
    }));
    return effects(streaming, {
      kind: "InjectPrompt",
      ocId: existing.ocId,
      text,
      messageId,
    });
  }

  return noEffects(store);
}

function reduceOcSessionCreated(
  store: SessionStore,
  ev: Extract<InputEvent, { kind: "OcSessionCreated" }>,
): Transition {
  const turn = store.pendingUiTurns.get(ev.ribId) ?? null;

  const pendingTurns = new Map(store.pendingUiTurns);
  pendingTurns.delete(ev.ribId);

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
  ];

  let injectedIds = new Set<string>();

  if (turn) {
    const text = formatPrompt(turn.tree, turn.event);
    const messageId = `msg-ribo-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    injectedIds.add(messageId);
    effs.push({ kind: "InjectPrompt", ocId: ev.ocId, text, messageId });
  }

  const state: SessionState = {
    ...makeSession(ev.ocId),
    ribId: Option.some(ev.ribId),
    phase: SessionPhase.Streaming("", 0, false, "", ""),
    queuedTurn: Option.none(),
    injectedMessageIds: injectedIds,
  };

  const nextStore = { ...putSession(store, state), pendingUiTurns: pendingTurns };
  return effects(nextStore, ...effs);
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
