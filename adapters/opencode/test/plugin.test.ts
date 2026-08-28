import { describe, it, expect } from "vitest";
import { Option } from "effect";
import { injectNonce, toInputEvent, type PartTypeIndex, type SourceEvent } from "../src/plugin.js";
import { createConfig } from "../src/types.js";

const config = createConfig("ws://127.0.0.1:8787", "start");

function partUpdatedEvent(
  part: { id: string; type: string; sessionID: string; messageID: string },
  delta?: string,
): SourceEvent {
  return {
    type: "message.part.updated",
    properties: { part: part as any, delta },
  };
}

function partDeltaEvent(props: {
  sessionID?: string;
  messageID?: string;
  partID?: string;
  delta?: string;
}): SourceEvent {
  return {
    type: "message.part.delta",
    properties: {
      sessionID: props.sessionID ?? "",
      messageID: props.messageID ?? "",
      partID: props.partID ?? "",
      field: "text",
      delta: props.delta,
    },
  };
}

function unwrap(opt: Option.Option<unknown>): unknown {
  const v = Option.getOrUndefined(opt);
  if (v === undefined) throw new Error("expected Some, got None");
  return v;
}

function translate(
  event: SourceEvent,
  partTypes: PartTypeIndex = new Map<string, string>(),
): { event: Option.Option<unknown>; partTypes: PartTypeIndex } {
  return toInputEvent(event, partTypes);
}

describe("toInputEvent — message.part.updated", () => {
  it("maps a text part to PartUpdated and records its type", () => {
    const { event, partTypes } = translate(
      partUpdatedEvent({ id: "p1", type: "text", sessionID: "oc-1", messageID: "m1" }, "hello"),
    );

    expect(unwrap(event)).toEqual({
      kind: "PartUpdated",
      ocId: "oc-1",
      messageId: "m1",
      partType: "text",
      delta: Option.some("hello"),
    });
    expect(partTypes.get("p1")).toBe("text");
  });

  it("records non-text part types for delta classification", () => {
    const { partTypes } = translate(
      partUpdatedEvent({ id: "p1", type: "reasoning", sessionID: "oc-1", messageID: "m1" }),
    );
    expect(partTypes.get("p1")).toBe("reasoning");
  });

  it("returns an unchanged index when the part type is already known", () => {
    const index = new Map<string, string>([["p1", "text"]]);
    const { partTypes } = translate(
      partUpdatedEvent({ id: "p1", type: "text", sessionID: "oc-1", messageID: "m1" }),
      index,
    );
    expect(partTypes.get("p1")).toBe("text");
    expect(index).not.toBe(partTypes);
  });

  it("maps a part without delta to Option none", () => {
    const { event } = translate(
      partUpdatedEvent({ id: "p1", type: "text", sessionID: "oc-1", messageID: "m1" }),
    );
    expect(unwrap(event)).toMatchObject({ delta: Option.none() });
  });
});

describe("toInputEvent — message.part.delta", () => {
  it("defaults unknown parts to text", () => {
    const { event } = translate(partDeltaEvent({ partID: "p-unknown", delta: "tok" }));
    expect(unwrap(event)).toEqual({
      kind: "PartUpdated",
      ocId: "",
      messageId: "",
      partType: "text",
      delta: Option.some("tok"),
    });
  });

  it("forwards deltas for parts known to be text", () => {
    const { event } = translate(
      partDeltaEvent({ sessionID: "oc-1", messageID: "m1", partID: "p1", delta: "tok" }),
      new Map([["p1", "text"]]),
    );
    expect(unwrap(event)).toEqual({
      kind: "PartUpdated",
      ocId: "oc-1",
      messageId: "m1",
      partType: "text",
      delta: Option.some("tok"),
    });
  });

  it("drops deltas for parts known to be non-text", () => {
    const { event } = translate(
      partDeltaEvent({ partID: "p1", delta: "tok" }),
      new Map([["p1", "reasoning"]]),
    );
    expect(Option.isNone(event)).toBe(true);
  });

  it("threads the index through unchanged", () => {
    const index = new Map<string, string>([["p1", "text"]]);
    const { partTypes } = translate(partDeltaEvent({ partID: "p1", delta: "tok" }), index);
    expect(partTypes).toBe(index);
  });
});

describe("toInputEvent — session events", () => {
  it("maps session.idle to SessionIdle", () => {
    const { event } = translate({ type: "session.idle", properties: { sessionID: "oc-1" } });
    expect(unwrap(event)).toEqual({ kind: "SessionIdle", ocId: "oc-1" });
  });

  it("maps session.error with error to a serialized Option some", () => {
    const err = { name: "AbortError", message: "killed" };
    const { event } = translate({
      type: "session.error",
      properties: { sessionID: "oc-1", error: err as any },
    });
    expect(unwrap(event)).toEqual({
      kind: "SessionError",
      ocId: "oc-1",
      error: Option.some(JSON.stringify(err)),
    });
  });

  it("maps session.error without error to Option none", () => {
    const { event } = translate({ type: "session.error", properties: {} });
    expect(unwrap(event)).toEqual({ kind: "SessionError", ocId: "", error: Option.none() });
  });

  it("yields None for unrelated events", () => {
    const { event } = translate(
      { type: "session.status", properties: { sessionID: "oc-1", status: { type: "busy" } } } as SourceEvent,
    );
    expect(Option.isNone(event)).toBe(true);
  });
});

describe("injectNonce", () => {
  it("injects nonce and harness session id for the start tool", () => {
    const args: Record<string, unknown> = { foo: "bar" };
    const nonce = Option.getOrThrow(injectNonce("start", "oc-1", args, config));
    expect(nonce).toMatch(/^oc-[a-z0-9]+$/);
    expect(args._nonce).toBe(nonce);
    expect(args._harness_session_id).toBe("oc-1");
  });

  it("matches a namespaced start tool", () => {
    const args: Record<string, unknown> = {};
    const nonce = Option.getOrThrow(injectNonce("mcp__start", "oc-1", args, config));
    expect(nonce).toMatch(/^oc-[a-z0-9]+$/);
    expect(args._nonce).toBe(nonce);
  });

  it("leaves non-start tools untouched", () => {
    const args: Record<string, unknown> = { foo: "bar" };
    const nonce = injectNonce("bash", "oc-1", args, config);
    expect(Option.isNone(nonce)).toBe(true);
    expect(args).toEqual({ foo: "bar" });
  });

  it("yields None when args are null or non-object", () => {
    expect(Option.isNone(injectNonce("start", "oc-1", null, config))).toBe(true);
    expect(Option.isNone(injectNonce("start", "oc-1", "nope", config))).toBe(true);
    expect(Option.isNone(injectNonce("start", "oc-1", 42, config))).toBe(true);
  });
});