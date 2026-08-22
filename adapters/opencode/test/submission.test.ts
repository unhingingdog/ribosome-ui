import { describe, it, expect } from "vitest";
import {
  createSubmissionInjector,
  formatSubmission,
} from "../src/submission.js";

function makeInjector() {
  const activeSessions = new Set<string>(["oc-1"]);
  const harnessSessionIdMap = new Map<string, string>([["oc-1", "rs-1"]]);
  return createSubmissionInjector(activeSessions, harnessSessionIdMap);
}

const sampleTree = JSON.stringify({
  type: "column",
  children: [{ type: "text", text: "Hello" }],
});

const sampleEvent = JSON.stringify({
  type: "submit",
  target: "form1",
  values: { name: "Alice", age: 30 },
});

describe("formatSubmission", () => {
  it("wraps tree and event in ribosome tags", () => {
    const text = formatSubmission(sampleTree, sampleEvent);

    expect(text).toContain("[ribosome-tree]");
    expect(text).toContain(sampleTree);
    expect(text).toContain("[/ribosome-tree]");
    expect(text).toContain("[ribosome-event]");
    expect(text).toContain("[/ribosome-event]");
  });

  it("pretty-prints the event JSON", () => {
    const text = formatSubmission(sampleTree, sampleEvent);
    expect(text).toContain('"type": "submit"');
  });

  it("preserves values in the event", () => {
    const text = formatSubmission(sampleTree, sampleEvent);
    expect(text).toContain('"name": "Alice"');
    expect(text).toContain('"age": 30');
  });
});

describe("submission injector", () => {
  it("returns payload for first user_turn on idle session", () => {
    const inj = makeInjector();

    const payload = inj.handleUserTurn({
      kind: "user_turn",
      session_id: "rs-1",
      tree: sampleTree,
      event: sampleEvent,
    });

    expect(payload).not.toBeNull();
    expect(payload!.sessionID).toBe("oc-1");
    expect(payload!.text).toContain("[ribosome-tree]");
    expect(payload!.text).toContain("[ribosome-event]");
    expect(inj.hasActive("oc-1")).toBe(true);
  });

  it("returns null for unknown ribosome session", () => {
    const inj = makeInjector();

    const payload = inj.handleUserTurn({
      kind: "user_turn",
      session_id: "rs-unknown",
      tree: sampleTree,
      event: sampleEvent,
    });

    expect(payload).toBeNull();
  });

  it("queues at most one submission while busy", () => {
    const inj = makeInjector();

    const first = inj.handleUserTurn({
      kind: "user_turn",
      session_id: "rs-1",
      tree: sampleTree,
      event: sampleEvent,
    });
    expect(first).not.toBeNull();

    const second = inj.handleUserTurn({
      kind: "user_turn",
      session_id: "rs-1",
      tree: sampleTree,
      event: sampleEvent,
    });
    expect(second).toBeNull();
    expect(inj.isQueued("oc-1")).toBe(true);
    expect(inj.queuedCount).toBe(1);

    const third = inj.handleUserTurn({
      kind: "user_turn",
      session_id: "rs-1",
      tree: sampleTree,
      event: sampleEvent,
    });
    expect(third).toBeNull();
    expect(inj.queuedCount).toBe(1);
  });

  it("flushes queued submission on idle", () => {
    const inj = makeInjector();

    inj.handleUserTurn({
      kind: "user_turn",
      session_id: "rs-1",
      tree: sampleTree,
      event: sampleEvent,
    });
    inj.handleUserTurn({
      kind: "user_turn",
      session_id: "rs-1",
      tree: sampleTree,
      event: sampleEvent,
    });

    const flushed = inj.flushQueue("oc-1");
    expect(flushed).not.toBeNull();
    expect(flushed!.sessionID).toBe("oc-1");
    expect(inj.isQueued("oc-1")).toBe(false);
    expect(inj.hasActive("oc-1")).toBe(true);
  });

  it("returns null when flushing with empty queue", () => {
    const inj = makeInjector();

    inj.handleUserTurn({
      kind: "user_turn",
      session_id: "rs-1",
      tree: sampleTree,
      event: sampleEvent,
    });

    const flushed = inj.flushQueue("oc-1");
    expect(flushed).toBeNull();
    expect(inj.hasActive("oc-1")).toBe(false);
  });

  it("clears all state for a session", () => {
    const inj = makeInjector();

    inj.handleUserTurn({
      kind: "user_turn",
      session_id: "rs-1",
      tree: sampleTree,
      event: sampleEvent,
    });
    inj.handleUserTurn({
      kind: "user_turn",
      session_id: "rs-1",
      tree: sampleTree,
      event: sampleEvent,
    });

    inj.clear("oc-1");
    expect(inj.hasActive("oc-1")).toBe(false);
    expect(inj.isQueued("oc-1")).toBe(false);
    expect(inj.queuedCount).toBe(0);
  });

  it("isolates submissions across parallel sessions", () => {
    const activeSessions = new Set<string>(["oc-1", "oc-2"]);
    const harnessSessionIdMap = new Map<string, string>([
      ["oc-1", "rs-1"],
      ["oc-2", "rs-2"],
    ]);
    const inj = createSubmissionInjector(activeSessions, harnessSessionIdMap);

    const p1 = inj.handleUserTurn({
      kind: "user_turn",
      session_id: "rs-1",
      tree: sampleTree,
      event: sampleEvent,
    });
    const p2 = inj.handleUserTurn({
      kind: "user_turn",
      session_id: "rs-2",
      tree: sampleTree,
      event: sampleEvent,
    });

    expect(p1!.sessionID).toBe("oc-1");
    expect(p2!.sessionID).toBe("oc-2");
    expect(inj.hasActive("oc-1")).toBe(true);
    expect(inj.hasActive("oc-2")).toBe(true);
  });
});
