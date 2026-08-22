import { describe, it, expect } from "vitest";
import { createDeltaForwarder } from "../src/delta.js";

function makeForwarder() {
  const activeSessions = new Set<string>(["oc-1"]);
  const harnessSessionIdMap = new Map<string, string>([["oc-1", "rs-1"]]);
  return createDeltaForwarder(activeSessions, harnessSessionIdMap);
}

describe("delta forwarder", () => {
  it("starts generation lazily on first delta and forwards with seq 0", () => {
    const fwd = makeForwarder();

    const msg = fwd.handlePartDelta("oc-1", "msg-1", "text", "Hello");

    expect(msg).not.toBeNull();
    expect(msg!.kind).toBe("delta");
    expect(msg!.session_id).toBe("rs-1");
    expect(msg!.generation_id).toBe("msg-1");
    expect(msg!.seq).toBe(0);
    expect(msg!.content).toBe("Hello");
    expect(fwd.activeGenerationCount).toBe(1);
  });

  it("five deltas produce five harness delta messages with incrementing seq", () => {
    const fwd = makeForwarder();

    const msgs = [];
    for (let i = 0; i < 5; i++) {
      const m = fwd.handlePartDelta("oc-1", "msg-1", "text", `chunk-${i}`);
      if (m) msgs.push(m);
    }

    expect(msgs.length).toBe(5);
    expect(msgs.map((m) => m.seq)).toEqual([0, 1, 2, 3, 4]);
    expect(msgs.map((m) => m.content)).toEqual([
      "chunk-0",
      "chunk-1",
      "chunk-2",
      "chunk-3",
      "chunk-4",
    ]);
    expect(msgs.every((m) => m.generation_id === "msg-1")).toBe(true);
  });

  it("ignores non-text parts", () => {
    const fwd = makeForwarder();

    const msg = fwd.handlePartDelta("oc-1", "msg-1", "reasoning", "thinking");

    expect(msg).toBeNull();
    expect(fwd.activeGenerationCount).toBe(0);
  });

  it("ignores undefined delta", () => {
    const fwd = makeForwarder();

    const msg = fwd.handlePartDelta("oc-1", "msg-1", "text", undefined);

    expect(msg).toBeNull();
  });

  it("ignores inactive sessions", () => {
    const activeSessions = new Set<string>(["oc-1"]);
    const harnessSessionIdMap = new Map<string, string>([["oc-1", "rs-1"]]);
    const fwd = createDeltaForwarder(activeSessions, harnessSessionIdMap);

    const msg = fwd.handlePartDelta("oc-unknown", "msg-1", "text", "Hello");

    expect(msg).toBeNull();
  });

  it("completes generation on session.idle", () => {
    const fwd = makeForwarder();

    fwd.handlePartDelta("oc-1", "msg-1", "text", "Hello");
    const completed = fwd.handleSessionIdle("oc-1");

    expect(completed).not.toBeNull();
    expect(completed!.kind).toBe("generation_completed");
    expect(completed!.session_id).toBe("rs-1");
    expect(completed!.generation_id).toBe("msg-1");
    expect(fwd.activeGenerationCount).toBe(0);
  });

  it("returns null on session.idle with no active generation", () => {
    const fwd = makeForwarder();

    expect(fwd.handleSessionIdle("oc-1")).toBeNull();
  });

  it("reports session error as generation failure", () => {
    const fwd = makeForwarder();

    fwd.handlePartDelta("oc-1", "msg-1", "text", "Hello");
    const failed = fwd.handleSessionError("oc-1", "API timeout");

    expect(failed).not.toBeNull();
    expect(failed!.kind).toBe("generation_failed");
    expect(failed!.session_id).toBe("rs-1");
    expect(failed!.generation_id).toBe("msg-1");
    expect(failed!.reason).toBe("API timeout");
    expect(fwd.activeGenerationCount).toBe(0);
  });

  it("reports session error with null reason when no message", () => {
    const fwd = makeForwarder();

    fwd.handlePartDelta("oc-1", "msg-1", "text", "Hello");
    const failed = fwd.handleSessionError("oc-1");

    expect(failed!.reason).toBeNull();
  });

  it("clears generation", () => {
    const fwd = makeForwarder();

    fwd.handlePartDelta("oc-1", "msg-1", "text", "Hello");
    expect(fwd.activeGenerationCount).toBe(1);

    fwd.clearGeneration("oc-1");
    expect(fwd.activeGenerationCount).toBe(0);
  });

  it("isolates generations across parallel sessions", () => {
    const activeSessions = new Set<string>(["oc-1", "oc-2"]);
    const harnessSessionIdMap = new Map<string, string>([
      ["oc-1", "rs-1"],
      ["oc-2", "rs-2"],
    ]);
    const fwd = createDeltaForwarder(activeSessions, harnessSessionIdMap);

    const m1 = fwd.handlePartDelta("oc-1", "msg-a", "text", "a1");
    const m2 = fwd.handlePartDelta("oc-2", "msg-b", "text", "b1");
    const m3 = fwd.handlePartDelta("oc-1", "msg-a", "text", "a2");

    expect(m1!.session_id).toBe("rs-1");
    expect(m2!.session_id).toBe("rs-2");
    expect(m3!.session_id).toBe("rs-1");
    expect(m1!.generation_id).toBe("msg-a");
    expect(m2!.generation_id).toBe("msg-b");
    expect(m3!.seq).toBe(1);
  });
});
