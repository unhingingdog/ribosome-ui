import { describe, it, expect } from "vitest";
import { decodeTemplate, decodeTemplateNode } from "../src/codec/template-decode";
import type { Template } from "../src/types/template";

function tree(kind: string, extra: Record<string, unknown> = {}): string {
  return JSON.stringify({ kind, id: "test-1", ...extra });
}

describe("decodeTemplate — top-level kinds", () => {
  it("decodes text", () => {
    const r = decodeTemplate(tree("text", { text_type: "H1", value: "Hello" }));
    expect(r.ok).toBe(true);
    if (r.ok) expect(r.value.kind).toBe("text");
  });

  it("decodes image", () => {
    const r = decodeTemplate(tree("image", { src: "https://x.png", alt: "X" }));
    expect(r.ok).toBe(true);
    if (r.ok) expect(r.value.kind).toBe("image");
  });

  it("decodes badge", () => {
    const r = decodeTemplate(tree("badge", { label: "OK", variant: "Success" }));
    expect(r.ok).toBe(true);
    if (r.ok) expect(r.value.kind).toBe("badge");
  });

  it("decodes stat", () => {
    const r = decodeTemplate(tree("stat", { label: "CPU", value: "42%" }));
    expect(r.ok).toBe(true);
    if (r.ok) expect(r.value.kind).toBe("stat");
  });

  it("decodes stat with secondary", () => {
    const r = decodeTemplate(tree("stat", { label: "CPU", value: "42%", secondary: "avg 30%" }));
    expect(r.ok).toBe(true);
    if (r.ok && r.value.kind === "stat") expect(r.value.secondary).toBe("avg 30%");
  });

  it("decodes divider", () => {
    const r = decodeTemplate(tree("divider"));
    expect(r.ok).toBe(true);
  });

  it("decodes divider with label", () => {
    const r = decodeTemplate(tree("divider", { label: "Section" }));
    expect(r.ok).toBe(true);
    if (r.ok && r.value.kind === "divider") expect(r.value.label).toBe("Section");
  });

  it("decodes diagram", () => {
    const r = decodeTemplate(tree("diagram", {
      title: "Flow",
      size: { width: 400, height: 300 },
      primitives: [
        { kind: "line", start: { x: 0, y: 0 }, stop: { x: 10, y: 10 }, tone: "Default" },
        { kind: "arrow", start: { x: 0, y: 0 }, stop: { x: 10, y: 10 } },
        { kind: "rectangle", origin: { x: 0, y: 0 }, size: { width: 100, height: 50 } },
        { kind: "circle", center: { x: 50, y: 50 }, radius: 25 },
        { kind: "polyline", points: [{ x: 0, y: 0 }, { x: 10, y: 10 }] },
        { kind: "text", text: "Label", position: { x: 0, y: 0 } },
      ],
    }));
    expect(r.ok).toBe(true);
    if (r.ok && r.value.kind === "diagram") {
      expect(r.value.primitives).toHaveLength(6);
    }
  });

  it("decodes code with highlights", () => {
    const r = decodeTemplate(tree("code", {
      path: "src/main.ml",
      language: "ocaml",
      line_start: 1,
      source: "let () = ()",
      highlights: [{ start_line: 1, end_line: 1, tone: "Positive" }],
    }));
    expect(r.ok).toBe(true);
    if (r.ok && r.value.kind === "code") {
      expect(r.value.highlights).toHaveLength(1);
      expect(r.value.highlights[0].tone).toBe("Positive");
    }
  });

  it("decodes container with children", () => {
    const r = decodeTemplate(tree("container", {
      direction: "Vertical",
      children: [
        { kind: "text", id: "c1", text_type: "Paragraph", value: "Child 1" },
        { kind: "text", id: "c2", text_type: "Paragraph", value: "Child 2" },
      ],
    }));
    expect(r.ok).toBe(true);
    if (r.ok && r.value.kind === "container") {
      expect(r.value.children).toHaveLength(2);
      expect(r.value.direction).toBe("Vertical");
    }
  });

  it("decodes list ordered", () => {
    const r = decodeTemplate(tree("list", {
      children: [{ kind: "text", id: "c1", text_type: "Paragraph", value: "Item" }],
      ordered: true,
    }));
    expect(r.ok).toBe(true);
    if (r.ok && r.value.kind === "list") {
      expect(r.value.ordered).toBe(true);
    }
  });

  it("decodes list unordered (ordered omitted)", () => {
    const r = decodeTemplate(tree("list", {
      children: [],
    }));
    expect(r.ok).toBe(true);
    if (r.ok && r.value.kind === "list") {
      expect(r.value.ordered).toBeUndefined();
    }
  });

  it("decodes submittable with input, select, and button", () => {
    const r = decodeTemplate(tree("submittable", {
      value: [
        { kind: "input", id: "inp1", value: "hello" },
        { kind: "select", id: "sel1", label: "Pick", options: [{ value: "a", label: "A" }], selected: "a" },
      ],
      button: { kind: "button", id: "btn1", label: "Submit", action: "Submit" },
    }));
    expect(r.ok).toBe(true);
    if (r.ok && r.value.kind === "submittable") {
      expect(r.value.value).toHaveLength(2);
      expect(r.value.value[0].kind).toBe("input");
      expect(r.value.value[1].kind).toBe("select");
      expect(r.value.button?.label).toBe("Submit");
    }
  });

  it("decodes submittable without button", () => {
    const r = decodeTemplate(tree("submittable", { value: [] }));
    expect(r.ok).toBe(true);
    if (r.ok && r.value.kind === "submittable") {
      expect(r.value.button).toBeUndefined();
    }
  });

  it("decodes input with numeric value inside submittable", () => {
    const r = decodeTemplate(tree("submittable", {
      value: [{ kind: "input", id: "inp1", value: 42 }],
    }));
    expect(r.ok).toBe(true);
    if (r.ok && r.value.kind === "submittable") {
      expect(r.value.value[0].kind).toBe("input");
      if (r.value.value[0].kind === "input") expect(r.value.value[0].value).toBe(42);
    }
  });
});

describe("decodeTemplate — nested-only kinds rejected at root", () => {
  it("rejects input at root", () => {
    const r = decodeTemplate(tree("input", { value: "hi" }));
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error.field).toBe("kind");
  });

  it("rejects select at root", () => {
    const r = decodeTemplate(tree("select", { label: "x", options: [] }));
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error.field).toBe("kind");
  });

  it("rejects button at root", () => {
    const r = decodeTemplate(tree("button", { label: "Go", action: "Submit" }));
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error.field).toBe("kind");
  });
});

describe("decodeTemplate — error cases", () => {
  it("rejects invalid JSON", () => {
    const r = decodeTemplate("not json");
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error.message).toBe("invalid JSON");
  });

  it("rejects unknown kind", () => {
    const r = decodeTemplate(tree("bogus"));
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error.field).toBe("kind");
  });

  it("rejects missing kind field", () => {
    const r = decodeTemplate(JSON.stringify({ id: "x" }));
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error.field).toBe("kind");
  });

  it("rejects invalid badge variant", () => {
    const r = decodeTemplate(tree("badge", { label: "x", variant: "Purple" }));
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error.field).toBe("variant");
  });

  it("rejects invalid text_type", () => {
    const r = decodeTemplate(tree("text", { text_type: "H7", value: "x" }));
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error.field).toBe("text_type");
  });

  it("rejects invalid tone in diagram primitive", () => {
    const r = decodeTemplate(tree("diagram", {
      title: "x",
      size: { width: 10, height: 10 },
      primitives: [{ kind: "line", start: { x: 0, y: 0 }, stop: { x: 1, y: 1 }, tone: "Purple" }],
    }));
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error.field).toBe("tone");
  });
});

describe("decodeTemplateNode — nested kinds allowed with flag", () => {
  it("decodes input when allowNested=true", () => {
    const r = decodeTemplateNode({ kind: "input", id: "i1", value: "hi" }, true);
    expect(r.ok).toBe(false);
  });

  it("container children can contain any top-level kind", () => {
    const r = decodeTemplate(JSON.stringify({
      kind: "container",
      id: "root",
      direction: "Horizontal",
      children: [
        { kind: "text", id: "t1", text_type: "Paragraph", value: "a" },
        { kind: "badge", id: "b1", label: "x", variant: "Neutral" },
      ],
    }));
    expect(r.ok).toBe(true);
  });
});
