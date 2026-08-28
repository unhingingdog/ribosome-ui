import { describe, it, expect } from "vitest";
import { Option } from "effect";
import { reduce } from "../src/reduce.js";
import {
  createConfig,
  emptyStore,
  makeSession,
  putSession,
  removeSession,
  SessionPhase,
  type SessionStore,
  type InputEvent,
  type Effect,
} from "../src/types.js";

const config = createConfig("ws://127.0.0.1:8787", "start");

function storeWithSession(ocId: string, overrides?: Partial<ReturnType<typeof makeSession>>): SessionStore {
  return putSession(emptyStore(), { ...makeSession(ocId), ...overrides });
}

function reduceAll(store: SessionStore, events: InputEvent[]): { store: SessionStore; effects: readonly Effect[] } {
  let s = store;
  let allEffects: Effect[] = [];
  for (const ev of events) {
    const t = reduce(s, ev, config);
    s = t.store;
    allEffects = allEffects.concat(t.effects);
  }
  return { store: s, effects: allEffects };
}

function filterEffects(effects: readonly Effect[], kind: string): Effect[] {
  return effects.filter((e) => e.kind === kind);
}

function harnessMsgs(effects: readonly Effect[]): Effect[] {
  return effects.filter((e) => e.kind === "SendHarness");
}

describe("reduce — ToolBefore", () => {
  it("stores nonce and kickoff state for start tool", () => {
    const store = emptyStore();
    const ev: InputEvent = {
      kind: "ToolBefore",
      ocId: "oc-1",
      tool: "start",
      callId: "call-1",
nonce: Option.some("nonce-abc"),
    };
    const t = reduce(store, ev, config);
    const session = t.store.sessions.get("oc-1");
    expect(session).toBeDefined();
    expect(session!.phase._tag).toBe("KickoffPending");
    expect(Option.getOrNull(session!.nonce)).toBe("nonce-abc");
    expect(t.effects).toHaveLength(0);
  });

  it("ignores non-start tools", () => {
    const store = emptyStore();
    const ev: InputEvent = {
      kind: "ToolBefore",
      ocId: "oc-1",
      tool: "other_tool",
      callId: "call-1",
      nonce: Option.none(),
    };
    const t = reduce(store, ev, config);
    expect(t.store.sessions.size).toBe(0);
    expect(t.effects).toHaveLength(0);
  });
});

describe("reduce — ToolAfter", () => {
  it("activates session and sends attach with ribosome session id", () => {
    const store = storeWithSession("oc-1", {
      phase: SessionPhase.KickoffPending("call-1"),
      nonce: Option.some("nonce-abc"),
    });
    const ev: InputEvent = {
      kind: "ToolAfter",
      ocId: "oc-1",
      tool: "start",
      callId: "call-1",
      output: JSON.stringify({ session_id: "rs-1", ui_nonce: "ui-nonce" }),
    };
    const t = reduce(store, ev, config);

    const session = t.store.sessions.get("oc-1");
    expect(session!.phase._tag).toBe("Streaming");
    expect(Option.getOrNull(session!.ribId)).toBe("rs-1");

    const sends = harnessMsgs(t.effects);
    expect(sends).toHaveLength(1);
    expect((sends[0] as any).msg.kind).toBe("attach");
    expect((sends[0] as any).msg.session_id).toBe("rs-1");
    expect((sends[0] as any).msg.harness_session_id).toBe("oc-1");
    expect((sends[0] as any).msg.nonce).toBe("nonce-abc");
  });

  it("activates session when start result arrives as a raw object (MCP structuredContent)", () => {
    const store = storeWithSession("oc-1", {
      phase: SessionPhase.KickoffPending("call-1"),
      nonce: Option.some("nonce-abc"),
    });
    const ev: InputEvent = {
      kind: "ToolAfter",
      ocId: "oc-1",
      tool: "start",
      callId: "call-1",
      output: { session_id: "rs-1", ui_nonce: "ui-nonce", mode: "ui" },
    };
    const t = reduce(store, ev, config);

    const session = t.store.sessions.get("oc-1");
    expect(session!.phase._tag).toBe("Streaming");
    expect(Option.getOrNull(session!.ribId)).toBe("rs-1");

    const sends = harnessMsgs(t.effects);
    expect(sends).toHaveLength(1);
    expect((sends[0] as any).msg.kind).toBe("attach");
    expect((sends[0] as any).msg.session_id).toBe("rs-1");
    expect((sends[0] as any).msg.harness_session_id).toBe("oc-1");
    expect((sends[0] as any).msg.nonce).toBe("nonce-abc");
  });

  it("returns to idle on non-JSON start result", () => {
    const store = storeWithSession("oc-1", {
      phase: SessionPhase.KickoffPending("call-1"),
      nonce: Option.some("nonce-abc"),
    });
    const ev: InputEvent = {
      kind: "ToolAfter",
      ocId: "oc-1",
      tool: "start",
      callId: "call-1",
      output: "something went wrong",
    };
    const t = reduce(store, ev, config);
    expect(t.store.sessions.get("oc-1")!.phase._tag).toBe("Idle");
  });
});

describe("reduce — PartUpdated", () => {
  function streamingStore(ocId = "oc-1", ribId = "rs-1"): SessionStore {
    return storeWithSession(ocId, {
      ribId: Option.some(ribId),
      phase: SessionPhase.Streaming("", 0, false, "", ""),
    });
  }

  it("accumulates content into buffer after JSON start", () => {
    const store = streamingStore();
    const ev: InputEvent = {
      kind: "PartUpdated",
      ocId: "oc-1",
      messageId: "msg-1",
      partType: "text",
      delta: Option.some(`{"ki`),
    };
    const t = reduce(store, ev, config);
    const phase = t.store.sessions.get("oc-1")!.phase;
    expect(phase._tag).toBe("Streaming");
    if (phase._tag === "Streaming") {
      expect(phase.genId).toBe("msg-1");
      expect(phase.jsonStarted).toBe(true);
      expect(phase.buffer).toBe(`{"ki`);
    }
  });

  it("skips non-JSON prefix before first { or [", () => {
    const store = streamingStore();

    const t1 = reduce(store, {
      kind: "PartUpdated",
      ocId: "oc-1",
      messageId: "msg-1",
      partType: "text",
      delta: Option.some("\n\n  Sure! "),
    }, config);
    let phase = t1.store.sessions.get("oc-1")!.phase;
    expect(phase._tag).toBe("Streaming");
    if (phase._tag === "Streaming") {
      expect(phase.jsonStarted).toBe(false);
      expect(phase.buffer).toBe("");
    }

    const t2 = reduce(t1.store, {
      kind: "PartUpdated",
      ocId: "oc-1",
      messageId: "msg-1",
      partType: "text",
      delta: Option.some(`{"kind":"text"`),
    }, config);
    phase = t2.store.sessions.get("oc-1")!.phase;
    if (phase._tag === "Streaming") {
      expect(phase.jsonStarted).toBe(true);
      expect(phase.buffer).toBe(`{"kind":"text"`);
    }
  });

  it("ignores non-text parts", () => {
    const store = streamingStore();
    const t = reduce(store, {
      kind: "PartUpdated",
      ocId: "oc-1",
      messageId: "msg-1",
      partType: "reasoning",
      delta: Option.some("thinking..."),
    }, config);
    const phase = t.store.sessions.get("oc-1")!.phase;
    if (phase._tag === "Streaming") {
      expect(phase.buffer).toBe("");
    }
  });

  it("ignores undefined delta", () => {
    const store = streamingStore();
    const t = reduce(store, {
      kind: "PartUpdated",
      ocId: "oc-1",
      messageId: "msg-1",
      partType: "text",
      delta: Option.none(),
    }, config);
    const phase = t.store.sessions.get("oc-1")!.phase;
    if (phase._tag === "Streaming") {
      expect(phase.buffer).toBe("");
    }
  });

  it("filters out injected message IDs (user prompt echo)", () => {
    const injected = new Set(["injected-msg-1"]);
    const store = storeWithSession("oc-1", {
      ribId: Option.some("rs-1"),
      phase: SessionPhase.Streaming("", 0, false, "", ""),
      injectedMessageIds: injected,
    });
    const t = reduce(store, {
      kind: "PartUpdated",
      ocId: "oc-1",
      messageId: "injected-msg-1",
      partType: "text",
      delta: Option.some("user prompt text"),
    }, config);
    const phase = t.store.sessions.get("oc-1")!.phase;
    if (phase._tag === "Streaming") {
      expect(phase.buffer).toBe("");
    }
  });

  it("starts new generation from idle on first delta", () => {
    const store = storeWithSession("oc-1", {
      ribId: Option.some("rs-1"),
      phase: SessionPhase.Idle(),
    });
    const t = reduce(store, {
      kind: "PartUpdated",
      ocId: "oc-1",
      messageId: "msg-1",
      partType: "text",
      delta: Option.some(`{"x":1}`),
    }, config);
    const phase = t.store.sessions.get("oc-1")!.phase;
    expect(phase._tag).toBe("Streaming");
    if (phase._tag === "Streaming") {
      expect(phase.genId).toBe("msg-1");
      expect(phase.buffer).toBe(`{"x":1}`);
    }
  });
});

describe("reduce — FlushBatch", () => {
  it("emits delta with buffered content and increments seq", () => {
    const store = storeWithSession("oc-1", {
      ribId: Option.some("rs-1"),
      phase: SessionPhase.Streaming("msg-1", 0, true, `{"kind":"text"`, ""),
    });
    const t = reduce(store, { kind: "FlushBatch", ocId: "oc-1" }, config);

    const sends = harnessMsgs(t.effects);
    expect(sends).toHaveLength(1);
    expect((sends[0] as any).msg.kind).toBe("delta");
    expect((sends[0] as any).msg.content).toBe(`{"kind":"text"`);
    expect((sends[0] as any).msg.seq).toBe(0);

    const phase = t.store.sessions.get("oc-1")!.phase;
    if (phase._tag === "Streaming") {
      expect(phase.seq).toBe(1);
      expect(phase.buffer).toBe("");
    }
  });

  it("emits nothing when buffer is empty", () => {
    const store = storeWithSession("oc-1", {
      ribId: Option.some("rs-1"),
      phase: SessionPhase.Streaming("msg-1", 0, true, "", ""),
    });
    const t = reduce(store, { kind: "FlushBatch", ocId: "oc-1" }, config);
    expect(t.effects).toHaveLength(0);
  });
});

describe("reduce — SessionIdle", () => {
  it("flushes remaining buffer and sends generation_completed", () => {
    const store = storeWithSession("oc-1", {
      ribId: Option.some("rs-1"),
      phase: SessionPhase.Streaming("msg-1", 0, true, `{"x":1}`, ""),
    });
    const t = reduce(store, { kind: "SessionIdle", ocId: "oc-1" }, config);

    const sends = harnessMsgs(t.effects);
    expect(sends).toHaveLength(2);
    expect((sends[0] as any).msg.kind).toBe("delta");
    expect((sends[1] as any).msg.kind).toBe("generation_completed");
    expect((sends[1] as any).msg.generation_id).toBe("msg-1");
  });

  it("sends only generation_completed when buffer is empty", () => {
    const store = storeWithSession("oc-1", {
      ribId: Option.some("rs-1"),
      phase: SessionPhase.Streaming("msg-1", 0, true, "", ""),
    });
    const t = reduce(store, { kind: "SessionIdle", ocId: "oc-1" }, config);

    const sends = harnessMsgs(t.effects);
    expect(sends).toHaveLength(1);
    expect((sends[0] as any).msg.kind).toBe("generation_completed");
  });

  it("transitions to AwaitingTurn when no queued turn", () => {
    const store = storeWithSession("oc-1", {
      ribId: Option.some("rs-1"),
      phase: SessionPhase.Streaming("msg-1", 0, true, "", ""),
    });
    const t = reduce(store, { kind: "SessionIdle", ocId: "oc-1" }, config);
    expect(t.store.sessions.get("oc-1")!.phase._tag).toBe("AwaitingTurn");
  });

  it("flushes queued turn on idle after completion", () => {
    const turn = { sessionId: "rs-1", tree: '{"type":"column"}', event: '{"type":"submit"}' };
    const store = storeWithSession("oc-1", {
      ribId: Option.some("rs-1"),
      phase: SessionPhase.Streaming("msg-1", 0, true, "", ""),
      queuedTurn: Option.some(turn),
    });
    const t = reduce(store, { kind: "SessionIdle", ocId: "oc-1" }, config);

    expect(t.store.sessions.get("oc-1")!.phase._tag).toBe("Streaming");
    expect(Option.isNone(t.store.sessions.get("oc-1")!.queuedTurn)).toBe(true);

    const injects = t.effects.filter((e) => e.kind === "InjectPrompt");
    expect(injects).toHaveLength(1);
  });
});

describe("reduce — SessionError", () => {
  it("emits generation_failed when streaming", () => {
    const store = storeWithSession("oc-1", {
      ribId: Option.some("rs-1"),
      phase: SessionPhase.Streaming("msg-1", 0, true, "", ""),
    });
    const t = reduce(store, {
      kind: "SessionError",
      ocId: "oc-1",
      error: Option.some("API timeout"),
    }, config);

    const sends = harnessMsgs(t.effects);
    expect(sends).toHaveLength(1);
    expect((sends[0] as any).msg.kind).toBe("generation_failed");
    expect((sends[0] as any).msg.reason).toBe("API timeout");
    expect(t.store.sessions.has("oc-1")).toBe(false);
  });

  it("emits failed with null reason when no error string", () => {
    const store = storeWithSession("oc-1", {
      ribId: Option.some("rs-1"),
      phase: SessionPhase.Streaming("msg-1", 0, true, "", ""),
    });
    const t = reduce(store, {
      kind: "SessionError",
      ocId: "oc-1",
      error: Option.none(),
    }, config);

    const sends = harnessMsgs(t.effects);
    expect((sends[0] as any).msg.reason).toBeNull();
  });

  it("just removes session when not streaming", () => {
    const store = storeWithSession("oc-1", {
      ribId: Option.some("rs-1"),
      phase: SessionPhase.AwaitingTurn(),
    });
    const t = reduce(store, {
      kind: "SessionError",
      ocId: "oc-1",
      error: Option.none(),
    }, config);
    expect(t.store.sessions.has("oc-1")).toBe(false);
    expect(t.effects).toHaveLength(0);
  });
});

describe("reduce — UserTurnRecv", () => {
  it("creates oc session for unknown ribId (UI-initiated)", () => {
    const store = emptyStore();
    const t = reduce(store, {
      kind: "UserTurnRecv",
      ribId: "rs-unknown",
      tree: '{"type":"column"}',
      event: '{"type":"submit"}',
    }, config);

    expect(t.store.pendingUiTurns.has("rs-unknown")).toBe(true);
    const creates = t.effects.filter((e) => e.kind === "CreateOcSession");
    expect(creates).toHaveLength(1);
    expect((creates[0] as any).ribId).toBe("rs-unknown");
  });

  it("injects prompt when session is idle", () => {
    const store = storeWithSession("oc-1", {
      ribId: Option.some("rs-1"),
      phase: SessionPhase.AwaitingTurn(),
    });
    const t = reduce(store, {
      kind: "UserTurnRecv",
      ribId: "rs-1",
      tree: '{"type":"column"}',
      event: '{"type":"submit"}',
    }, config);

    expect(t.store.sessions.get("oc-1")!.phase._tag).toBe("Streaming");
    const injects = t.effects.filter((e) => e.kind === "InjectPrompt");
    expect(injects).toHaveLength(1);
  });

  it("queues turn when session is streaming", () => {
    const store = storeWithSession("oc-1", {
      ribId: Option.some("rs-1"),
      phase: SessionPhase.Streaming("msg-1", 0, true, "", ""),
    });
    const t = reduce(store, {
      kind: "UserTurnRecv",
      ribId: "rs-1",
      tree: '{"type":"column"}',
      event: '{"type":"submit"}',
    }, config);

    expect(Option.isSome(t.store.sessions.get("oc-1")!.queuedTurn)).toBe(true);
    expect(t.effects).toHaveLength(0);
  });

  it("does not queue when a turn is already queued", () => {
    const existingTurn = { sessionId: "rs-1", tree: "old", event: "old" };
    const store = storeWithSession("oc-1", {
      ribId: Option.some("rs-1"),
      phase: SessionPhase.Streaming("msg-1", 0, true, "", ""),
      queuedTurn: Option.some(existingTurn),
    });
    const t = reduce(store, {
      kind: "UserTurnRecv",
      ribId: "rs-1",
      tree: "new",
      event: "new",
    }, config);

    const queued = t.store.sessions.get("oc-1")!.queuedTurn;
    if (Option.isSome(queued)) {
      expect(queued.value.tree).toBe("old");
    }
  });
});

describe("reduce — OcSessionCreated", () => {
  it("creates session and injects pending turn", () => {
    const turn = { sessionId: "rs-1", tree: '{"type":"column"}', event: '{"type":"submit"}' };
    const store = { ...emptyStore(), pendingUiTurns: new Map([["rs-1", turn]]) };
    const t = reduce(store, {
      kind: "OcSessionCreated",
      ocId: "oc-auto-1",
      ribId: "rs-1",
    }, config);

    const session = t.store.sessions.get("oc-auto-1");
    expect(session).toBeDefined();
    expect(Option.getOrNull(session!.ribId)).toBe("rs-1");
    expect(session!.phase._tag).toBe("Streaming");
    expect(t.store.pendingUiTurns.has("rs-1")).toBe(false);

    const injects = t.effects.filter((e) => e.kind === "InjectPrompt");
    expect(injects).toHaveLength(1);
  });
});

describe("reduce — InjectPrompt carries messageId", () => {
  it("UserTurnRecv on idle session generates messageId and pre-records it", () => {
    const store = storeWithSession("oc-1", {
      ribId: Option.some("rs-1"),
      phase: SessionPhase.AwaitingTurn(),
    });
    const t = reduce(store, {
      kind: "UserTurnRecv",
      ribId: "rs-1",
      tree: '{"kind":"container"}',
      event: '{"type":"submit"}',
    }, config);

    expect(t.store.sessions.get("oc-1")!.phase._tag).toBe("Streaming");
    const injects = t.effects.filter((e) => e.kind === "InjectPrompt");
    expect(injects).toHaveLength(1);
    if (injects[0].kind === "InjectPrompt") {
      expect(injects[0].messageId).toBeDefined();
      expect(t.store.sessions.get("oc-1")!.injectedMessageIds.has(injects[0].messageId)).toBe(true);
    }
  });

  it("OcSessionCreated generates messageId and pre-records it", () => {
    const turn = { sessionId: "rs-1", tree: '{"type":"column"}', event: '{"type":"submit"}' };
    const store = { ...emptyStore(), pendingUiTurns: new Map([["rs-1", turn]]) };
    const t = reduce(store, {
      kind: "OcSessionCreated",
      ocId: "oc-auto-1",
      ribId: "rs-1",
    }, config);

    const session = t.store.sessions.get("oc-auto-1")!;
    expect(session.phase._tag).toBe("Streaming");
    const injects = t.effects.filter((e) => e.kind === "InjectPrompt");
    expect(injects).toHaveLength(1);
    if (injects[0].kind === "InjectPrompt") {
      expect(session.injectedMessageIds.has(injects[0].messageId)).toBe(true);
    }
  });
});

describe("reduce — full two-turn flow", () => {
  it("end-to-end: kickoff → stream → complete → user turn → stream again", () => {
    let store = emptyStore();

    // ToolBefore: start tool
    let t = reduce(store, {
      kind: "ToolBefore",
      ocId: "oc-1",
      tool: "start",
      callId: "call-1",
      nonce: Option.some("nonce-abc"),
    }, config);
    store = t.store;
    expect(t.effects).toHaveLength(0);

    // ToolAfter: start returns session_id, sends attach
    t = reduce(store, {
      kind: "ToolAfter",
      ocId: "oc-1",
      tool: "start",
      callId: "call-1",
      output: JSON.stringify({ session_id: "rs-1", ui_nonce: "ui-1" }),
    }, config);
    store = t.store;
    expect(store.sessions.get("oc-1")!.phase._tag).toBe("Streaming");
    expect(harnessMsgs(t.effects)).toHaveLength(1);
    expect((harnessMsgs(t.effects)[0] as any).msg.kind).toBe("attach");
    expect((harnessMsgs(t.effects)[0] as any).msg.session_id).toBe("rs-1");
    expect((harnessMsgs(t.effects)[0] as any).msg.nonce).toBe("nonce-abc");

    // PartUpdated: stream some JSON
    t = reduce(store, {
      kind: "PartUpdated",
      ocId: "oc-1",
      messageId: "msg-1",
      partType: "text",
      delta: Option.some(`{"kind":"text","id":"t1","text_type":"H2","value":"Hi"}`),
    }, config);
    store = t.store;

    // FlushBatch: emit delta
    t = reduce(store, { kind: "FlushBatch", ocId: "oc-1" }, config);
    store = t.store;
    expect(harnessMsgs(t.effects)).toHaveLength(1);
    expect((harnessMsgs(t.effects)[0] as any).msg.kind).toBe("delta");

    // SessionIdle: complete generation
    t = reduce(store, { kind: "SessionIdle", ocId: "oc-1" }, config);
    store = t.store;
    const completedSends = harnessMsgs(t.effects).filter(
      (e) => (e as any).msg.kind === "generation_completed",
    );
    expect(completedSends).toHaveLength(1);
    expect(store.sessions.get("oc-1")!.phase._tag).toBe("AwaitingTurn");

    // UserTurnRecv: user submits — phase goes directly to Streaming
    t = reduce(store, {
      kind: "UserTurnRecv",
      ribId: "rs-1",
      tree: '{"kind":"container","id":"root"}',
      event: '{"type":"submit","target":"form1"}',
    }, config);
    store = t.store;
    expect(store.sessions.get("oc-1")!.phase._tag).toBe("Streaming");
    const injectEff = t.effects.find((e) => e.kind === "InjectPrompt");
    expect(injectEff).toBeDefined();
    const injectedMsgId = (injectEff as any).messageId;
    expect(store.sessions.get("oc-1")!.injectedMessageIds.has(injectedMsgId)).toBe(true);

    // PartUpdated: model response (should not be filtered — different messageId)
    t = reduce(store, {
      kind: "PartUpdated",
      ocId: "oc-1",
      messageId: "msg-2",
      partType: "text",
      delta: Option.some(`{"kind":"text","id":"t2"}`),
    }, config);
    store = t.store;
    const phase = store.sessions.get("oc-1")!.phase;
    if (phase._tag === "Streaming") {
      expect(phase.genId).toBe("msg-2");
      expect(phase.buffer).toBe(`{"kind":"text","id":"t2"}`);
    }
  });
});
