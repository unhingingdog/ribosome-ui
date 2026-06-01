import { describe, it, expect } from "vitest";
import { create, process_delta } from "./output/telomere/Balancer.js";

// Unwrap helpers
const ok = (result) => result.TAG === 0 ? result._0 : null;
const err = (result) => result.TAG === 1 ? result._0 : null;

// Feed an array of string chunks through the balancer, threading state.
// Both Ok and Error carry a state — always thread it forward.
// Returns the final result from the last delta.
const stateOf = (result) => ok(result)?.[1] ?? err(result)?.[1];

const stream = (chunks) => {
  let state = create();
  let result = null;
  for (const chunk of chunks) {
    result = process_delta(state, chunk);
    state = stateOf(result) ?? state;
  }
  return result;
};

// Feed a single complete string in one shot.
const feed = (input) => process_delta(create(), input);

// The full template JSON we stream through — covers:
//   object, array, nested objects, string values, number values,
//   boolean values, null, escaped string content, unicode (NotClosable soft error)
const fullTemplate = JSON.stringify({
  kind: "container",
  id: "root-1",
  count: 3,
  enabled: true,
  ratio: 1.5,
  label: null,
  title: "Hello, \"world\"",
  children: [
    { kind: "text", id: "t1", content: "line one" },
    { kind: "image", id: "img-1", src: "/a.png", alt: "an image" },
    { kind: "input", id: "inp-1", value: 42 },
  ],
});

describe("Balancer — already complete input", () => {
  it("returns empty completion string for complete JSON object", () => {
    const result = feed('{"a":1}');
    expect(ok(result)?.[0]).toBe("");
  });

  it("returns empty completion string for complete JSON array", () => {
    const result = feed("[1,2,3]");
    expect(ok(result)?.[0]).toBe("");
  });
});

describe("Balancer — partial input completions", () => {
  it("completes an unclosed object", () => {
    const result = feed('{"key":"val"');
    expect(ok(result)?.[0]).toBe("}");
  });

  it("completes a nested unclosed structure", () => {
    const result = feed('{"a":{"b":1');
    expect(ok(result)?.[0]).toBe("}}");
  });

  it("completes an unclosed array", () => {
    const result = feed("[1,2");
    expect(ok(result)?.[0]).toBe("]");
  });

  it("completes an unclosed array inside an object", () => {
    const result = feed('{"items":[1,2');
    expect(ok(result)?.[0]).toBe("]}");
  });

  it("completes a deeply nested structure", () => {
    // {"a":[{"b":[1  →  needs ]}]}
    const result = feed('{"a":[{"b":[1');
    expect(ok(result)?.[0]).toBe("]}]}");
  });

  it("completes an open string value", () => {
    const result = feed('{"key":"val');
    expect(ok(result)?.[0]).toBe('"}');
  });

  it("partial boolean 'tru' is not yet closable (NonCompletable)", () => {
    // "tru" is an incomplete prefix — not a valid terminal value
    const result = feed('{"flag":tru');
    expect(err(result)?.[0]).toBe(0); // NotClosable
  });

  it("partial null 'nul' is not yet closable (NonCompletable)", () => {
    const result = feed('{"x":nul');
    expect(err(result)?.[0]).toBe(0); // NotClosable
  });

  it("completes after a complete boolean value", () => {
    const result = feed('{"flag":true');
    expect(ok(result)?.[0]).toBe("}");
  });

  it("completes after a complete null value", () => {
    const result = feed('{"x":null');
    expect(ok(result)?.[0]).toBe("}");
  });

  it("completes a partial number value", () => {
    const result = feed('{"n":42');
    expect(ok(result)?.[0]).toBe("}");
  });
});

describe("Balancer — streaming (multiple process_delta calls)", () => {
  it("threads state across chunks for simple object", () => {
    const chunks = ['{"ke', 'y":', '"val', '"}'];
    const result = stream(chunks);
    expect(ok(result)?.[0]).toBe("");
  });

  it("gives correct completion midstream", () => {
    // After key + colon + partial value, completion is '"}' (close string + close object)
    const s1 = process_delta(create(), '{"key":');
    // s1 is NotClosable (after colon, expecting value) — state is still valid
    const state1 = err(s1)[1];
    const s2 = process_delta(state1, '"val');
    expect(ok(s2)?.[0]).toBe('"}');
  });

  it("streams the full template JSON and completes to empty string", () => {
    const chunkSize = 12;
    const chunks = [];
    for (let i = 0; i < fullTemplate.length; i += chunkSize) {
      chunks.push(fullTemplate.slice(i, i + chunkSize));
    }
    const result = stream(chunks);
    expect(ok(result)?.[0]).toBe("");
  });

  it("completion reaches empty string by end of full template", () => {
    // Feed the full template in small chunks and assert the final completion is empty.
    // Completion length can grow mid-stream as new nesting levels open.
    const chunkSize = 8;
    let state = create();
    let lastCompletion = null;
    for (let i = 0; i < fullTemplate.length; i += chunkSize) {
      const chunk = fullTemplate.slice(i, i + chunkSize);
      const result = process_delta(state, chunk);
      state = stateOf(result) ?? state;
      const r = ok(result);
      if (r) lastCompletion = r[0];
    }
    expect(lastCompletion).toBe("");
  });
});

describe("Balancer — not yet closable", () => {
  it("returns NotClosable for input ending after colon", () => {
    const result = feed('{"key":');
    expect(err(result)?.[0]).toBe(0); // NotClosable = 0
  });

  it("returns NotClosable for dangling comma in object", () => {
    const result = feed('{"a":1,');
    expect(err(result)?.[0]).toBe(0);
  });

  it("returns NotClosable for dangling comma in array", () => {
    const result = feed("[1,");
    expect(err(result)?.[0]).toBe(0);
  });
});

describe("Balancer — corrupted input", () => {
  it("returns error for mismatched closing token", () => {
    const result = feed('{"a":1]');
    expect(err(result)).not.toBeNull();
  });

  it("poisons state on hard error — subsequent calls return Corrupted", () => {
    const r1 = feed('{"a":1]'); // hard error
    const poisoned = err(r1)[1];
    expect(poisoned.is_corrupted).toBe(true);
    const r2 = process_delta(poisoned, '{"b":2}');
    expect(err(r2)?.[0]).toBe(1); // Corrupted = 1
  });

  it("returns error for invalid character", () => {
    const result = feed('{"a":$}');
    expect(err(result)).not.toBeNull();
  });
});
