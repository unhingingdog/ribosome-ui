import { describe, it, expect } from "vitest";
import { Either } from "effect";
import {
  encodeHarnessOutbound,
  decodeHarnessInbound,
} from "../src/protocol.js";
import type { HarnessOutbound } from "../src/types.js";

describe("protocol — encode/decode", () => {
  it("encodes attach message", () => {
    const msg: HarnessOutbound = {
      kind: "attach",
      session_id: "rs-1",
      harness_session_id: "oc-1",
      nonce: "abc123",
    };
    const json = encodeHarnessOutbound(msg);
    const parsed = JSON.parse(json);
    expect(parsed.kind).toBe("attach");
    expect(parsed.session_id).toBe("rs-1");
    expect(parsed.harness_session_id).toBe("oc-1");
    expect(parsed.nonce).toBe("abc123");
  });

  it("encodes delta message", () => {
    const msg: HarnessOutbound = {
      kind: "delta",
      session_id: "rs-1",
      generation_id: "msg-1",
      seq: 0,
      content: `{"kind":"text"`,
    };
    const json = encodeHarnessOutbound(msg);
    const parsed = JSON.parse(json);
    expect(parsed.kind).toBe("delta");
    expect(parsed.seq).toBe(0);
    expect(parsed.content).toBe(`{"kind":"text"`);
  });

  it("encodes generation_completed", () => {
    const msg: HarnessOutbound = {
      kind: "generation_completed",
      session_id: "rs-1",
      generation_id: "msg-1",
    };
    const json = encodeHarnessOutbound(msg);
    expect(JSON.parse(json).kind).toBe("generation_completed");
  });

  it("encodes generation_failed with reason", () => {
    const msg: HarnessOutbound = {
      kind: "generation_failed",
      session_id: "rs-1",
      generation_id: "msg-1",
      reason: "timeout",
    };
    const json = encodeHarnessOutbound(msg);
    const parsed = JSON.parse(json);
    expect(parsed.kind).toBe("generation_failed");
    expect(parsed.reason).toBe("timeout");
  });

  it("decodes valid user_turn message", () => {
    const data = JSON.stringify({
      kind: "user_turn",
      session_id: "rs-1",
      tree: '{"type":"column"}',
      event: '{"type":"submit"}',
    });
    const result = decodeHarnessInbound(data);
    expect(Either.isRight(result)).toBe(true);
    if (Either.isRight(result)) {
      expect(result.right.session_id).toBe("rs-1");
      expect(result.right.tree).toBe('{"type":"column"}');
    }
  });

  it("rejects invalid JSON", () => {
    const result = decodeHarnessInbound("not json");
    expect(Either.isLeft(result)).toBe(true);
  });

  it("rejects wrong kind", () => {
    const data = JSON.stringify({ kind: "ack", session_id: "rs-1" });
    const result = decodeHarnessInbound(data);
    expect(Either.isLeft(result)).toBe(true);
  });

  it("rejects missing session_id", () => {
    const data = JSON.stringify({
      kind: "user_turn",
      tree: "{}",
      event: "{}",
    });
    const result = decodeHarnessInbound(data);
    expect(Either.isLeft(result)).toBe(true);
  });

  it("rejects missing tree", () => {
    const data = JSON.stringify({
      kind: "user_turn",
      session_id: "rs-1",
      event: "{}",
    });
    const result = decodeHarnessInbound(data);
    expect(Either.isLeft(result)).toBe(true);
  });
});
