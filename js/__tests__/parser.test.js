import { describe, it, expect } from "vitest";
import { parse_data } from "../output/engine/Parser.js";

// Handle ugly translation from ocaml ADTs
const unwrap = (result) => {
  if (result?.TAG === 1) return undefined; // Error
  const value = result?._0;
  if (value?.TAG === 5) return undefined; // Broken (Soft or Hard)
  return value;
};

const exampleTemplate = {
  kind: "image",
  id: "1",
  src: "/img.png",
  alt: "test",
};

const exampleContainer = {
  kind: "container",
  id: "2",
  children: [exampleTemplate],
};

const corruptChildrenContainer = {
  kind: "container",
  id: "3",
  children: "not an array",
};

const nonContainerWithChildren = {
  kind: "image",
  id: "4",
  src: "/img.png",
  alt: "test",
  children: [exampleTemplate],
};

const exampleText = {
  kind: "text",
  id: "greetingText",
  text_type: "H1",
  value: "Welcome! Please enter your name:",
};

const exampleSubmittable = {
  kind: "submittable",
  id: "nameInputForm",
  value: [
    {
      kind: "input",
      id: "nameInput",
      value: "",
    },
  ],
};

const exampleGeneratedContainer = {
  kind: "container",
  id: "greetingContainer",
  children: [exampleText, exampleSubmittable],
};

describe("Parser", () => {
  it("parses a valid image", () => {
    const result = unwrap(parse_data(JSON.stringify(exampleTemplate)));
    expect(result).toBeDefined();
  });

  it("returns undefined for missing field", () => {
    const missingField = structuredClone(exampleTemplate);
    delete missingField.src;
    const result = unwrap(parse_data(JSON.stringify(missingField)));
    expect(result).toBeUndefined();
  });

  it("returns undefined for syntactically invalid json", () => {
    const result = unwrap(
      parse_data(
        JSON.stringify(exampleTemplate).slice(0, exampleTemplate.length - 2),
      ),
    );
    expect(result).toBeUndefined();
  });

  it("returns undefined for unknown kind", () => {
    const unknownKind = structuredClone(exampleTemplate);
    unknownKind.kind = "huh";
    const result = unwrap(parse_data(JSON.stringify(unknownKind)));
    expect(result).toBeUndefined();
  });

  it("parses a container with valid children", () => {
    const result = unwrap(parse_data(JSON.stringify(exampleContainer)));
    expect(result).toBeDefined();
  });

  it("parses generated text and submittable public JSON", () => {
    const result = unwrap(parse_data(JSON.stringify(exampleGeneratedContainer)));

    expect(result).toBeDefined();
  });

  it("rejects legacy tagged input value JSON", () => {
    const result = unwrap(parse_data(JSON.stringify({
      kind: "input",
      id: "legacyInput",
      value: ["String", "Ada"],
    })));

    expect(result).toBeUndefined();
  });

  it("returns undefined for container with corrupt children field", () => {
    const result = unwrap(parse_data(JSON.stringify(corruptChildrenContainer)));
    expect(result).toBeUndefined();
  });

  it("returns undefined for non-container with children", () => {
    const result = unwrap(parse_data(JSON.stringify(nonContainerWithChildren)));
    expect(result).toBeUndefined();
  });
});
