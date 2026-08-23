import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { decodeServerMessage } from "../src/codec/decode";
import { decodeTemplate } from "../src/codec/template-decode";
import { COMPONENT_KINDS, REJECTION_REASONS } from "../src/types/protocol";

const fixturePath = join(
  __dirname,
  "..",
  "..",
  "..",
  "..",
  "ribosome-server",
  "test",
  "protocol-fixtures",
  "ui.json",
);

const fixture = JSON.parse(readFileSync(fixturePath, "utf-8")) as {
  version: string;
  protocol: string;
  messages: Record<string, Record<string, unknown>>;
  enum_strings: {
    component_kinds: string[];
    rejection_reasons: string[];
  };
};

describe("UI protocol contract fixtures", () => {
  it("fixture version matches expected", () => {
    expect(fixture.version).toBe("0.0.0");
  });

  it("fixture protocol is ui", () => {
    expect(fixture.protocol).toBe("ui");
  });

  it("enum_strings component_kinds match TypeScript constants", () => {
    expect(fixture.enum_strings.component_kinds).toEqual([...COMPONENT_KINDS]);
  });

  it("enum_strings rejection_reasons match TypeScript constants", () => {
    expect(fixture.enum_strings.rejection_reasons).toEqual([...REJECTION_REASONS]);
  });

  it("decodes session_state fixture", () => {
    const raw = JSON.stringify(fixture.messages.session_state);
    const result = decodeServerMessage(raw);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.kind).toBe("session_state");
      if (result.value.kind === "session_state") {
        expect(result.value.session_id).toBe("rs-1");
        expect(result.value.mode).toBe("ui");
        expect(result.value.revision).toBe(1);
      }
    }
  });

  it("decodes template_update fixture", () => {
    const raw = JSON.stringify(fixture.messages.template_update);
    const result = decodeServerMessage(raw);
    expect(result.ok).toBe(true);
    if (result.ok && result.value.kind === "template_update") {
      expect(result.value.revision).toBe(2);
    }
  });

  it("decodes event_rejection_stale fixture", () => {
    const raw = JSON.stringify(fixture.messages.event_rejection_stale);
    const result = decodeServerMessage(raw);
    expect(result.ok).toBe(true);
    if (result.ok && result.value.kind === "event_rejection") {
      expect(result.value.reason).toBe("stale_revision");
    }
  });

  it("decodes event_rejection_duplicate fixture", () => {
    const raw = JSON.stringify(fixture.messages.event_rejection_duplicate);
    const result = decodeServerMessage(raw);
    expect(result.ok).toBe(true);
    if (result.ok && result.value.kind === "event_rejection") {
      expect(result.value.reason).toBe("duplicate_event_id");
    }
  });

  it("template tree in session_state fixture decodes as valid template", () => {
    const treeJson = fixture.messages.session_state.tree as string;
    const result = decodeTemplate(treeJson);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.kind).toBe("container");
    }
  });

  it("template tree in template_update fixture decodes as valid template", () => {
    const treeJson = fixture.messages.template_update.tree as string;
    const result = decodeTemplate(treeJson);
    expect(result.ok).toBe(true);
    if (result.ok && result.value.kind === "container") {
      expect(result.value.direction).toBe("Vertical");
      expect(result.value.children).toHaveLength(0);
    }
  });

  it("component_event fixtures have valid component_kinds", () => {
    for (const [name, msg] of Object.entries(fixture.messages)) {
      if (msg.kind === "component_event") {
        expect(COMPONENT_KINDS).toContain(msg.component_kind);
      }
    }
  });
});
