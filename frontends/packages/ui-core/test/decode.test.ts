import { describe, it, expect } from "vitest";
import { decodeServerMessage } from "../src/codec/decode";

describe("decodeServerMessage", () => {
  it("decodes session_state with tree", () => {
    const raw = JSON.stringify({
      kind: "session_state",
      session_id: "rs-1",
      mode: "ui",
      revision: 1,
      tree: '{"kind":"container","id":"root","direction":"Vertical","children":[]}',
    });
    const result = decodeServerMessage(raw);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.kind).toBe("session_state");
      if (result.value.kind === "session_state") {
        expect(result.value.session_id).toBe("rs-1");
        expect(result.value.mode).toBe("ui");
        expect(result.value.revision).toBe(1);
        expect(result.value.tree).toBe('{"kind":"container","id":"root","direction":"Vertical","children":[]}');
      }
    }
  });

  it("decodes session_state with generation_id", () => {
    const raw = JSON.stringify({
      kind: "session_state",
      session_id: "rs-1",
      mode: "ui",
      revision: 3,
      tree: '{"kind":"container","id":"root","direction":"Vertical","children":[]}',
      generation_id: "msg-1",
    });
    const result = decodeServerMessage(raw);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.kind).toBe("session_state");
      if (result.value.kind === "session_state") {
        expect(result.value.generation_id).toBe("msg-1");
      }
    }
  });

  it("decodes session_state without tree", () => {
    const raw = JSON.stringify({
      kind: "session_state",
      session_id: "rs-1",
      mode: "ui",
      revision: 0,
    });
    const result = decodeServerMessage(raw);
    expect(result.ok).toBe(true);
    if (result.ok && result.value.kind === "session_state") {
      expect(result.value.tree).toBeUndefined();
      expect(result.value.generation_id).toBeUndefined();
    }
  });

  it("decodes template_update", () => {
    const raw = JSON.stringify({
      kind: "template_update",
      session_id: "rs-1",
      revision: 2,
      tree: '{"kind":"container","id":"root","direction":"Vertical","children":[]}',
    });
    const result = decodeServerMessage(raw);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.kind).toBe("template_update");
      if (result.value.kind === "template_update") {
        expect(result.value.revision).toBe(2);
      }
    }
  });

  it("decodes event_rejection with stale_revision", () => {
    const raw = JSON.stringify({
      kind: "event_rejection",
      session_id: "rs-1",
      event_id: "evt-1",
      reason: "stale_revision",
    });
    const result = decodeServerMessage(raw);
    expect(result.ok).toBe(true);
    if (result.ok && result.value.kind === "event_rejection") {
      expect(result.value.reason).toBe("stale_revision");
      expect(result.value.event_id).toBe("evt-1");
    }
  });

  it("decodes event_rejection with duplicate_event_id", () => {
    const raw = JSON.stringify({
      kind: "event_rejection",
      session_id: "rs-1",
      event_id: "evt-1",
      reason: "duplicate_event_id",
    });
    const result = decodeServerMessage(raw);
    expect(result.ok).toBe(true);
    if (result.ok && result.value.kind === "event_rejection") {
      expect(result.value.reason).toBe("duplicate_event_id");
    }
  });

  it("rejects invalid JSON", () => {
    const result = decodeServerMessage("not json");
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.message).toBe("invalid JSON");
    }
  });

  it("rejects unknown message kind", () => {
    const raw = JSON.stringify({ kind: "unknown", session_id: "rs-1" });
    const result = decodeServerMessage(raw);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.field).toBe("kind");
    }
  });

  it("rejects missing kind field", () => {
    const raw = JSON.stringify({ session_id: "rs-1" });
    const result = decodeServerMessage(raw);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.field).toBe("kind");
    }
  });

  it("rejects invalid rejection reason", () => {
    const raw = JSON.stringify({
      kind: "event_rejection",
      session_id: "rs-1",
      event_id: "evt-1",
      reason: "bogus_reason",
    });
    const result = decodeServerMessage(raw);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.field).toBe("reason");
    }
  });
});
