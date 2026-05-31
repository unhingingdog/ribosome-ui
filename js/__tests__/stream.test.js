import { describe, expect, it } from "vitest";
import { create_sse_state, parse_sse_chunk } from "./output/engine/Stream.js";

const listToArray = (list) => {
  const items = [];
  let current = list;

  while (current !== 0) {
    items.push(current.hd);
    current = current.tl;
  }

  return items;
};

const data = (event) => event._0;
const isDone = (event) => typeof event === "number";

describe("Stream SSE parser", () => {
  it("emits data payloads from complete SSE lines", () => {
    const [events, state] = parse_sse_chunk(
      create_sse_state(),
      'data: {"kind":"text"}\n\n',
    );

    expect(listToArray(events).map(data)).toEqual(['{"kind":"text"}']);
    expect(state.pending_line).toBe("");
    expect(state.done_).toBe(false);
  });

  it("preserves a split data prefix across chunks", () => {
    let [events, state] = parse_sse_chunk(create_sse_state(), "dat");

    expect(listToArray(events)).toEqual([]);
    expect(state.pending_line).toBe("dat");

    [events, state] = parse_sse_chunk(state, 'a: {"kind":"text"}\n\n');

    expect(listToArray(events).map(data)).toEqual(['{"kind":"text"}']);
    expect(state.pending_line).toBe("");
  });

  it("preserves a split payload line across chunks", () => {
    let [events, state] = parse_sse_chunk(
      create_sse_state(),
      'data: {"kind":"text"',
    );

    expect(listToArray(events)).toEqual([]);
    expect(state.pending_line).toBe('data: {"kind":"text"');

    [events, state] = parse_sse_chunk(state, ',"id":"1"}\n\n');

    expect(listToArray(events).map(data)).toEqual(['{"kind":"text","id":"1"}']);
    expect(state.pending_line).toBe("");
  });

  it("reconstructs structured JSON split across chunks", () => {
    let state = create_sse_state();
    const payloads = [];

    for (const chunk of [
      'data: {"kind":"container","id":"root","children":[',
      '{"kind":"text","id":"intro","text_type":"Paragraph",',
      '"content":"Hello"},{"kind":"input","id":"name",',
      '"value":{"String":""}}]}\n\n',
    ]) {
      const [events, nextState] = parse_sse_chunk(state, chunk);
      payloads.push(...listToArray(events).map(data));
      state = nextState;
    }

    expect(payloads).toHaveLength(1);
    expect(JSON.parse(payloads[0])).toEqual({
      kind: "container",
      id: "root",
      children: [
        {
          kind: "text",
          id: "intro",
          text_type: "Paragraph",
          content: "Hello",
        },
        {
          kind: "input",
          id: "name",
          value: { String: "" },
        },
      ],
    });
    expect(state.pending_line).toBe("");
    expect(state.done_).toBe(false);
  });

  it("handles multiple data lines in one chunk", () => {
    const [events] = parse_sse_chunk(
      create_sse_state(),
      'data: {"a":1}\ndata: {"b":2}\n\n',
    );

    expect(listToArray(events).map(data)).toEqual(['{"a":1}', '{"b":2}']);
  });

  it("handles CRLF line endings", () => {
    const [events, state] = parse_sse_chunk(
      create_sse_state(),
      'data: {"a":1}\r\n\r\n',
    );

    expect(listToArray(events).map(data)).toEqual(['{"a":1}']);
    expect(state.pending_line).toBe("");
  });

  it("surfaces done and ignores future chunks", () => {
    let [events, state] = parse_sse_chunk(
      create_sse_state(),
      'data: {"a":1}\ndata: [DONE]\ndata: {"b":2}\n\n',
    );

    const eventArray = listToArray(events);
    expect(data(eventArray[0])).toBe('{"a":1}');
    expect(isDone(eventArray[1])).toBe(true);
    expect(eventArray).toHaveLength(2);
    expect(state.done_).toBe(true);
    expect(state.pending_line).toBe("");

    [events, state] = parse_sse_chunk(state, 'data: {"c":3}\n\n');

    expect(listToArray(events)).toEqual([]);
    expect(state.done_).toBe(true);
  });
});
