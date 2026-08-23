import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const fixturesDir = join(__dirname, "..", "..", "..", "ribosome-server", "test", "protocol-fixtures");

function loadFixture(name: string): any {
  const raw = readFileSync(join(fixturesDir, name), "utf-8");
  return JSON.parse(raw);
}

describe("harness contract fixtures", () => {
  const fixture = loadFixture("harness.json");

  it("version matches expected constant", () => {
    expect(fixture.version).toBe("0.0.0");
  });

  it("protocol is harness", () => {
    expect(fixture.protocol).toBe("harness");
  });

  it("attach has correct fields", () => {
    const m = fixture.messages.attach;
    expect(m.kind).toBe("attach");
    expect(typeof m.session_id).toBe("string");
    expect(typeof m.harness_session_id).toBe("string");
    expect(typeof m.nonce).toBe("string");
  });

  it("delta has correct fields", () => {
    const m = fixture.messages.delta;
    expect(m.kind).toBe("delta");
    expect(typeof m.session_id).toBe("string");
    expect(typeof m.generation_id).toBe("string");
    expect(typeof m.seq).toBe("number");
    expect(typeof m.content).toBe("string");
  });

  it("generation_completed has correct fields", () => {
    const m = fixture.messages.generation_completed;
    expect(m.kind).toBe("generation_completed");
    expect(typeof m.session_id).toBe("string");
    expect(typeof m.generation_id).toBe("string");
  });

  it("generation_failed has correct fields", () => {
    const m = fixture.messages.generation_failed;
    expect(m.kind).toBe("generation_failed");
    expect(typeof m.session_id).toBe("string");
    expect(typeof m.generation_id).toBe("string");
    expect(typeof m.reason).toBe("string");
  });

  it("user_turn has correct fields", () => {
    const m = fixture.messages.user_turn;
    expect(m.kind).toBe("user_turn");
    expect(typeof m.session_id).toBe("string");
    expect(typeof m.tree).toBe("string");
    expect(typeof m.event).toBe("string");
  });

  it("rejection enum strings match", () => {
    const reasons = fixture.enum_strings.rejection_reasons;
    expect(reasons).toEqual([
      "invalid_session",
      "invalid_generation",
      "invalid_sequence",
      "malformed_payload",
    ]);
  });
});

describe("ui contract fixtures", () => {
  const fixture = loadFixture("ui.json");

  it("version matches expected constant", () => {
    expect(fixture.version).toBe("0.0.0");
  });

  it("protocol is ui", () => {
    expect(fixture.protocol).toBe("ui");
  });

  it("component event kinds match", () => {
    expect(fixture.messages.component_event_click.component_kind).toBe("click");
    expect(fixture.messages.component_event_change.component_kind).toBe("change");
    expect(fixture.messages.component_event_submit.component_kind).toBe("submit");
  });

  it("component_kinds enum strings match", () => {
    expect(fixture.enum_strings.component_kinds).toEqual([
      "click",
      "change",
      "submit",
    ]);
  });

  it("rejection_reasons enum strings match", () => {
    expect(fixture.enum_strings.rejection_reasons).toEqual([
      "stale_revision",
      "duplicate_event_id",
    ]);
  });
});

describe("cross-implementation version guard", () => {
  it("harness and ui fixtures have same version", () => {
    const h = loadFixture("harness.json");
    const u = loadFixture("ui.json");
    expect(h.version).toBe(u.version);
  });

  it("version is not 99.0.0", () => {
    const h = loadFixture("harness.json");
    expect(h.version).not.toBe("99.0.0");
  });
});
