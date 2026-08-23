import { describe, it, expect } from "vitest";
import {
  encodeAttach,
  encodeComponentEvent,
  encodeCancel,
  encodeDisconnect,
} from "../src/codec/encode";

describe("encodeAttach", () => {
  it("encodes without revision", () => {
    const raw = encodeAttach("rs-1");
    const parsed = JSON.parse(raw);
    expect(parsed).toEqual({ kind: "attach", session_id: "rs-1" });
  });

  it("encodes with revision for reconnect", () => {
    const raw = encodeAttach("rs-1", 3);
    const parsed = JSON.parse(raw);
    expect(parsed).toEqual({ kind: "attach", session_id: "rs-1", revision: 3 });
  });
});

describe("encodeComponentEvent", () => {
  it("encodes click event without value", () => {
    const raw = encodeComponentEvent("rs-1", 1, "evt-1", "btn1", "click");
    const parsed = JSON.parse(raw);
    expect(parsed).toEqual({
      kind: "component_event",
      session_id: "rs-1",
      revision: 1,
      event_id: "evt-1",
      target_id: "btn1",
      component_kind: "click",
    });
  });

  it("encodes change event with string value", () => {
    const raw = encodeComponentEvent("rs-1", 1, "evt-2", "inp1", "change", "hello");
    const parsed = JSON.parse(raw);
    expect(parsed.value).toBe("hello");
    expect(parsed.component_kind).toBe("change");
  });

  it("encodes change event with numeric value", () => {
    const raw = encodeComponentEvent("rs-1", 1, "evt-3", "inp1", "change", 42);
    const parsed = JSON.parse(raw);
    expect(parsed.value).toBe(42);
  });

  it("encodes submit event without value", () => {
    const raw = encodeComponentEvent("rs-1", 2, "evt-4", "form1", "submit");
    const parsed = JSON.parse(raw);
    expect(parsed.component_kind).toBe("submit");
    expect(parsed).not.toHaveProperty("value");
  });
});

describe("encodeCancel", () => {
  it("encodes cancel", () => {
    const raw = encodeCancel("rs-1");
    const parsed = JSON.parse(raw);
    expect(parsed).toEqual({ kind: "cancel", session_id: "rs-1" });
  });
});

describe("encodeDisconnect", () => {
  it("encodes disconnect", () => {
    const raw = encodeDisconnect("rs-1");
    const parsed = JSON.parse(raw);
    expect(parsed).toEqual({ kind: "disconnect", session_id: "rs-1" });
  });
});
