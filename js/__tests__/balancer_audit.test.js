import { describe, it, expect } from "vitest";
import { create, process_delta } from "./output/telomere/Balancer.js";

const ok = (r) => r.TAG === 0 ? r._0 : null;
const err = (r) => r.TAG === 1 ? r._0 : null;
const completion = (r) => ok(r)?.[0] ?? null;
const stateOf    = (r) => ok(r)?.[1] ?? err(r)?.[1];
// NotClosable = plain 0; all other errors are either plain 1 (Corrupted)
// or a TAG:0 object (Char). The reliable signal for "hard error, stream poisoned"
// is is_corrupted on the returned state.
const isNotClosable = (r) => err(r)?.[0] === 0;
const isHardError   = (r) => stateOf(r)?.is_corrupted === true;

describe("Balancer — Pending", () => {
  it("empty input returns empty completion", () =>
    expect(completion(process_delta(create(), ""))).toBe(""));
  it("whitespace only returns empty completion", () =>
    expect(completion(process_delta(create(), "   "))).toBe(""));
});

describe("Balancer — Brace states", () => {
  it("Brace Empty: just '{'", () =>
    expect(completion(process_delta(create(), "{"))).toBe("}"));

  it("Brace ExpectingKey: dangling comma → NotClosable", () =>
    expect(isNotClosable(process_delta(create(), '{"a":1,'))).toBe(true));

  it("Brace InKey Open: mid-key → NotClosable", () =>
    expect(isNotClosable(process_delta(create(), '{"ke'))).toBe(true));

  it("Brace InKey Escaped: backslash in key → NotClosable", () =>
    expect(isNotClosable(process_delta(create(), '{"ke\\'))).toBe(true));

  it("Brace InKey Closed: key closed, no colon → NotClosable", () =>
    expect(isNotClosable(process_delta(create(), '{"key"'))).toBe(true));

  it("Brace ExpectingValue: after colon → NotClosable", () =>
    expect(isNotClosable(process_delta(create(), '{"a":'))).toBe(true));

  it("Brace InValue String Open: mid-string value → closable", () =>
    expect(completion(process_delta(create(), '{"a":"hel'))).toBe('"}'));

  it("Brace InValue String Escaped: backslash in value → NotClosable", () =>
    expect(isNotClosable(process_delta(create(), '{"a":"hel\\'))).toBe(true));

  it("Brace InValue String Closed: string value complete", () =>
    expect(completion(process_delta(create(), '{"a":"hello"'))).toBe("}"));

  it("Brace InValue NonString Completable: number", () =>
    expect(completion(process_delta(create(), '{"a":42'))).toBe("}"));

  it("Brace InValue NonString Completable: float", () =>
    expect(completion(process_delta(create(), '{"a":1.5'))).toBe("}"));

  it("Brace InValue NonString Completable: negative", () =>
    expect(completion(process_delta(create(), '{"a":-3'))).toBe("}"));

  it("Brace InValue NonString Completable: scientific", () =>
    expect(completion(process_delta(create(), '{"a":1e5'))).toBe("}"));

  it("Brace InValue NonString Completable: true", () =>
    expect(completion(process_delta(create(), '{"a":true'))).toBe("}"));

  it("Brace InValue NonString Completable: false", () =>
    expect(completion(process_delta(create(), '{"a":false'))).toBe("}"));

  it("Brace InValue NonString Completable: null", () =>
    expect(completion(process_delta(create(), '{"a":null'))).toBe("}"));

  it("Brace InValue NonString NonCompletable: partial literal 'tru' → NotClosable", () =>
    expect(isNotClosable(process_delta(create(), '{"a":tru'))).toBe(true));

  it("Brace InValue NonString NonCompletable: trailing exponent '1e' → NotClosable", () =>
    expect(isNotClosable(process_delta(create(), '{"a":1e'))).toBe(true));

  it("Brace InValue NonString NonCompletable: trailing '-' → NotClosable", () =>
    expect(isNotClosable(process_delta(create(), '{"a":-'))).toBe(true));

  it("Brace InValue NestedValueComplete: nested obj just closed", () =>
    expect(completion(process_delta(create(), '{"a":{"b":1}'))).toBe("}"));

  it("Brace InValue NestedValueComplete: nested arr just closed", () =>
    expect(completion(process_delta(create(), '{"a":[1,2]'))).toBe("}"));
});

describe("Balancer — Bracket states", () => {
  it("Bracket Empty: just '['", () =>
    expect(completion(process_delta(create(), "["))).toBe("]"));

  it("Bracket ExpectingValue: dangling comma → NotClosable", () =>
    expect(isNotClosable(process_delta(create(), "[1,"))).toBe(true));

  it("Bracket InValue String Open: mid-string → closable", () =>
    expect(completion(process_delta(create(), '["hel'))).toBe('"]'));

  it("Bracket InValue String Escaped: backslash in string → NotClosable", () =>
    expect(isNotClosable(process_delta(create(), '["hel\\'))).toBe(true));

  it("Bracket InValue String Closed: string complete", () =>
    expect(completion(process_delta(create(), '["hello"'))).toBe("]"));

  it("Bracket InValue NonString Completable: number", () =>
    expect(completion(process_delta(create(), "[42"))).toBe("]"));

  it("Bracket InValue NonString Completable: true", () =>
    expect(completion(process_delta(create(), "[true"))).toBe("]"));

  it("Bracket InValue NonString NonCompletable: '1e' → NotClosable", () =>
    expect(isNotClosable(process_delta(create(), "[1e"))).toBe(true));

  it("Bracket InValue NestedValueComplete: nested obj just closed", () =>
    expect(completion(process_delta(create(), '[{"a":1}'))).toBe("]"));

  it("Bracket InValue NestedValueComplete: nested arr just closed", () =>
    expect(completion(process_delta(create(), '[[1,2]'))).toBe("]"));
});

describe("Balancer — closing stack depth", () => {
  it("2 levels: unclosed obj in arr", () =>
    expect(completion(process_delta(create(), '[{"a":1'))).toBe("}]"));

  it("2 levels: unclosed arr in obj", () =>
    expect(completion(process_delta(create(), '{"a":[1'))).toBe("]}"));

  it("4 levels: deeply nested", () =>
    expect(completion(process_delta(create(), '{"a":{"b":{"c":{"d":1'))).toBe("}}}}"));

  it("stack with open key: mid-key inside nested obj → NotClosable", () =>
    expect(isNotClosable(process_delta(create(), '{"a":{"ke'))).toBe(true));

  it("stack with open string value: mid-string inside nested obj → closable", () =>
    expect(completion(process_delta(create(), '{"a":{"b":"hel'))).toBe('"}}'));
});

describe("Balancer — already complete", () => {
  it("complete flat object",          () => expect(completion(process_delta(create(), '{"a":1}'))).toBe(""));
  it("complete flat array",           () => expect(completion(process_delta(create(), '[1,2,3]'))).toBe(""));
  it("complete nested",               () => expect(completion(process_delta(create(), '{"a":{"b":2}}'))).toBe(""));
  it("empty object",                  () => expect(completion(process_delta(create(), '{}'))).toBe(""));
  it("empty array",                   () => expect(completion(process_delta(create(), '[]'))).toBe(""));
  it("array of objects complete",     () => expect(completion(process_delta(create(), '[{"a":1},{"b":2}]'))).toBe(""));
  it("string with escaped quote",     () => expect(completion(process_delta(create(), '{"a":"say \\"hi\\""}'))).toBe(""));
  it("string with backslash",         () => expect(completion(process_delta(create(), '{"a":"hel\\\\lo"}'))).toBe(""));
});

describe("Balancer — hard errors (stream poisoned)", () => {
  it("mismatched close bracket in obj → hard error", () =>
    expect(isHardError(process_delta(create(), '{"a":1]'))).toBe(true));

  it("close brace on empty stack → hard error", () =>
    expect(isHardError(process_delta(create(), '}'))).toBe(true));

  it("close bracket on empty stack → hard error", () =>
    expect(isHardError(process_delta(create(), ']'))).toBe(true));

  it("invalid character → hard error", () =>
    expect(isHardError(process_delta(create(), '{"a":$}'))).toBe(true));

  it("poisoned state fast-paths all subsequent calls", () => {
    const r1 = process_delta(create(), '{"a":1]');
    const poisoned = stateOf(r1);
    expect(poisoned.is_corrupted).toBe(true);
    const r2 = process_delta(poisoned, '{"b":2}');
    // Returns error and state is still corrupted
    expect(r2.TAG).toBe(1);
    expect(stateOf(r2).is_corrupted).toBe(true);
  });
});

describe("Balancer — streaming across chunk boundaries", () => {
  it("key split across chunks", () => {
    const s1 = process_delta(create(), '{"ke');
    const s2 = process_delta(stateOf(s1), 'y":1}');
    expect(completion(s2)).toBe("");
  });

  it("value split across chunks", () => {
    const s1 = process_delta(create(), '{"a":tr');
    const s2 = process_delta(stateOf(s1), 'ue}');
    expect(completion(s2)).toBe("");
  });

  it("string value split across chunks", () => {
    const s1 = process_delta(create(), '{"a":"hel');
    const s2 = process_delta(stateOf(s1), 'lo"');
    expect(completion(s2)).toBe("}");
  });

  it("escape split: backslash at end of chunk", () => {
    const s1 = process_delta(create(), '{"a":"hel\\');
    const s2 = process_delta(stateOf(s1), 'lo"');
    expect(completion(s2)).toBe("}");
  });

  it("full template streamed in 10-char chunks completes to empty string", () => {
    const full = JSON.stringify({
      kind: "container", id: "root-1", count: 3, enabled: true,
      ratio: 1.5, label: null, title: "Hello world",
      children: [
        { kind: "text", id: "t1", content: "line one" },
        { kind: "image", id: "img-1", src: "/a.png", alt: "an image" },
        { kind: "input", id: "inp-1", value: 42 },
      ],
    });
    let state = create();
    let last = null;
    for (let i = 0; i < full.length; i += 10) {
      const r = process_delta(state, full.slice(i, i + 10));
      state = stateOf(r) ?? state;
      if (ok(r)) last = ok(r)[0];
    }
    expect(last).toBe("");
  });
});
