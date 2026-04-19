import { describe, it, expect } from "vitest";
import { attempt_template_parse } from "./output/src/Parser.js";

// Handle ugly translation from ocaml ADTs
const unwrap = (result) => {
  if (result?.TAG === 1) return undefined;
  return result?._0;
};

const exampleTemplate = {
  kind: "image",
  id: "1",
  src: "/img.png",
  alt: "test",
};

describe("Parser", () => {
  it("parses a valid image", () => {
    const result = unwrap(
      attempt_template_parse(JSON.stringify(exampleTemplate)),
    );
    expect(result).toBeDefined();
  });

  it("returns undefined for missing field", () => {
    const missingField = structuredClone(exampleTemplate);
    delete missingField.src;
    const result = unwrap(attempt_template_parse(JSON.stringify(missingField)));
    expect(result).toBeUndefined();
  });

  it("returns undefined for syntactically invalid json", () => {
    const result = unwrap(
      attempt_template_parse(
        JSON.stringify(exampleTemplate).slice(0, exampleTemplate.length - 2),
      ),
    );
    expect(result).toBeUndefined();
  });

  it("returns undefined for unknown kind", () => {
    const unknownKind = structuredClone(exampleTemplate);
    unknownKind.kind = "huh";
    const result = unwrap(attempt_template_parse(JSON.stringify(unknownKind)));
    expect(result).toBeUndefined();
  });
});
