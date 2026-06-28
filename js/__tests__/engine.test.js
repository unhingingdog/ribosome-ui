import { afterEach, describe, expect, it, vi } from "vitest";
import {
  create_runtime,
  kick_off,
  on_chunk,
  on_done,
  reset_turn,
  run_turn,
  set_error,
  submit,
} from "../output/engine/Engine.js";

const listToArray = (list) => {
  const items = [];
  let current = list;

  while (current !== 0) {
    items.push(current.hd);
    current = current.tl;
  }

  return items;
};

const list = (items) =>
  items.reduceRight((tl, hd) => ({ hd, tl }), 0);

const config = (overrides = {}) => ({
  root: { TAG: 1, _0: "missing-root" },
  components: {},
  templates: 0,
  assets: 0,
  goal_prompt: "Render the first UI",
  request: vi.fn(() => ({ url: "/stream", headers: [], body: "{}" })),
  stream_adapter: vi.fn((payload) => ({ TAG: 0, _0: payload })),
  callbacks: {
    on_submit: vi.fn(),
    on_message_complete: vi.fn(),
    on_error: vi.fn(),
  },
  ...overrides,
});

const createRuntime = (overrides = {}) => {
  vi.stubGlobal("document", { querySelector: vi.fn(() => undefined) });
  return create_runtime(config(overrides));
};

const unresolvedFetch = () =>
  vi.stubGlobal("fetch", vi.fn(() => new Promise(() => {})));

const flushAsync = async () => {
  for (let i = 0; i < 10; i += 1) {
    await Promise.resolve();
  }
};

const encode = (value) => new TextEncoder().encode(value);

const streamResponse = (chunks) => {
  let index = 0;
  return {
    ok: true,
    status: 200,
    statusText: "OK",
    body: {
      getReader: () => ({
        read: vi.fn(() => {
          const value = chunks[index++];
          return Promise.resolve(
            value === undefined
              ? { done_: true }
              : { done_: false, value: encode(value) },
          );
        }),
      }),
    },
  };
};

const errorResponse = (status, statusText) => ({
  ok: false,
  status,
  statusText,
});

const submittableJson = (id, inputId) =>
  JSON.stringify({
    kind: "submittable",
    id,
    value: [
      {
        kind: "input",
        id: inputId,
        value: "",
      },
    ],
  });

const textJson = (id, content) =>
  JSON.stringify({
    kind: "text",
    id,
    text_type: ["Paragraph"],
    content,
  });

const submission = (templateId, inputId, value) => ({
  template_id: templateId,
  values: list([
    {
      id: inputId,
      value: { TAG: 1, _0: value },
    },
  ]),
});

describe("Engine runtime utilities", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it("records errors through runtime state and callbacks", () => {
    const t = createRuntime();

    set_error(t, "failed");

    expect(t.last_error).toBe("failed");
    expect(t.config.callbacks.on_error).toHaveBeenCalledWith("failed");
  });

  it("resets turn-local fields without clearing history", () => {
    const t = createRuntime();
    t.history = { hd: { role: 0, content: "kept" }, tl: 0 };
    t.last_template = { TAG: 3, _0: { id: "text" } };
    t.last_error = "failed";

    reset_turn(t);

    expect(listToArray(t.history)).toEqual([{ role: 0, content: "kept" }]);
    expect(t.last_template).toMatchObject({ TAG: 3, _0: { id: "text" } });
    expect(t.last_error).toBeUndefined();
  });

  it("run_turn appends user history and starts the configured request", () => {
    unresolvedFetch();
    const t = createRuntime();

    run_turn(t, "user submitted data");

    expect(listToArray(t.history)).toMatchObject([
      { role: 0, content: "user submitted data" },
    ]);
    expect(t.config.request).toHaveBeenCalledOnce();
    expect(fetch).toHaveBeenCalledWith(
      "/stream",
      expect.objectContaining({ method: "POST", body: "{}" }),
    );
  });

  it("processes a streamed template and completes", () => {
    unresolvedFetch();
    const t = createRuntime();
    const templateJson =
      '{"kind":"text","id":"intro","text_type":["Paragraph"],"content":"Hello"}';

    kick_off(t);
    on_chunk(t, templateJson);
    on_done(t, 0);

    expect(t.last_template).toMatchObject({ TAG: 2, _0: { id: "intro" } });
    expect(listToArray(t.history)).toMatchObject([
      { role: 0 },
    ]);
    expect(t.config.callbacks.on_message_complete).toHaveBeenCalledWith(t.last_template);
  });

  it("runs multiple UI-driven turns through rendered submit callbacks", () => {
    unresolvedFetch();
    const rendered = [];
    const Submittable = () => null;
    const Text = () => null;
    const t = createRuntime({
      components: {
        submittable: Submittable,
        image: undefined,
        text: Text,
        container: () => null,
        broken: () => null,
      },
    });
    t.renderer = (element) => rendered.push(element);

    const firstTemplate = submittableJson("step-one", "name");
    const secondTemplate = submittableJson("step-two", "color");
    const finalTemplate = textJson("done", "Finished");

    kick_off(t);
    on_chunk(t, firstTemplate);
    on_done(t, 0);

    expect(rendered.at(-1).type).toBe(Submittable);
    rendered.at(-1).props.on_submit(submission("step-one", "name", "Ada"));

    on_chunk(t, secondTemplate);
    on_done(t, 0);

    expect(rendered.at(-1).type).toBe(Submittable);
    rendered.at(-1).props.on_submit(submission("step-two", "color", "blue"));

    on_chunk(t, finalTemplate);
    on_done(t, 0);

    expect(rendered.at(-1).type).toBe(Text);
    expect(t.config.request).toHaveBeenCalledTimes(3);
    expect(t.config.callbacks.on_submit).toHaveBeenCalledTimes(2);
    expect(t.config.callbacks.on_message_complete).toHaveBeenCalledTimes(3);
    expect(t.config.callbacks.on_error).not.toHaveBeenCalled();
    expect(listToArray(t.history)).toMatchObject([
      { role: 0 },
      { role: 0 },
      { role: 0 },
    ]);
  });

  it("handles an HTTP response error on the second turn", async () => {
    const rendered = [];
    const Submittable = () => null;
    const firstTemplate = submittableJson("step-one", "name");

    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValueOnce(streamResponse([`data: ${firstTemplate}\n`]))
        .mockResolvedValueOnce(errorResponse(500, "Server Error")),
    );

    const t = createRuntime({
      components: {
        submittable: Submittable,
        image: undefined,
        text: () => null,
        container: () => null,
        broken: () => null,
      },
    });
    t.renderer = (element) => rendered.push(element);

    kick_off(t);
    await flushAsync();

    expect(rendered.at(-1).type).toBe(Submittable);
    expect(t.config.callbacks.on_message_complete).toHaveBeenCalledTimes(1);

    rendered.at(-1).props.on_submit(submission("step-one", "name", "Ada"));
    await flushAsync();

    expect(fetch).toHaveBeenCalledTimes(2);
    expect(t.config.callbacks.on_submit).toHaveBeenCalledTimes(1);
    expect(t.config.callbacks.on_error).toHaveBeenCalledWith(
      "HTTP request failed: 500 Server Error",
    );
    expect(t.last_error).toBe("HTTP request failed: 500 Server Error");
    expect(t.config.callbacks.on_message_complete).toHaveBeenCalledTimes(1);
    expect(listToArray(t.history)).toMatchObject([
      { role: 0 },
      { role: 0 },
    ]);
  });

  it("preserves full root tree after partial patch reconciliation", () => {
    unresolvedFetch();
    const t = createRuntime({
      components: {
        container: () => null,
        text: () => null,
        broken: () => null,
      },
    });

    // Turn 1: bot sends full root tree with multiple regions
    const firstTurn = JSON.stringify({
      kind: "container",
      id: "root",
      children: [
        { kind: "container", id: "header-region", children: [{ kind: "text", id: "title", text_type: ["H1"], content: "Flight Booking" }] },
        { kind: "container", id: "search-form-region", children: [{ kind: "submittable", id: "search-form", value: [{ kind: "input", id: "origin", value: "" }] }] },
        { kind: "container", id: "results-region", children: [{ kind: "text", id: "placeholder", text_type: ["Paragraph"], content: "Search to see results" }] },
        { kind: "container", id: "filters-region", children: [] },
      ],
    });

    kick_off(t);
    on_chunk(t, firstTurn);
    on_done(t, 0);

    // last_template should be full root tree
    expect(t.last_template.TAG).toBe(3); // Container
    const rootId = t.last_template._0.id;
    expect(rootId).toBe("root");

    // Turn 2: bot sends partial patch for results-region
    const secondTurn = JSON.stringify({
      kind: "container",
      id: "results-region",
      children: [
        { kind: "list", id: "flight-results", children: [
          { kind: "container", id: "flight-1", children: [{ kind: "text", id: "flight-1-name", text_type: ["Paragraph"], content: "Air NZ 123" }] },
        ] },
      ],
    });

    // Manually drive turn 2 as if user submitted
    // We need to trigger submit but since we don't have rendered components with callbacks,
    // we simulate by directly calling the internal flow
    // First, let's simulate what submit does: inject input and call run_turn
    // But actually, let's just verify that on_chunk with the patch preserves the full tree
    on_chunk(t, secondTurn);
    on_done(t, 0);

    // After reconciliation, last_template should STILL be the full root tree
    expect(t.last_template.TAG).toBe(3); // Container
    expect(t.last_template._0.id).toBe("root");
    // The root should have 4 children (header, search, results, filters)
    const children = listToArray(t.last_template._0.children);
    expect(children.length).toBe(4);
    expect(children[0]._0.id).toBe("header-region");
    expect(children[1]._0.id).toBe("search-form-region");
    expect(children[2]._0.id).toBe("results-region");
    expect(children[3]._0.id).toBe("filters-region");
    // The results-region should now have the list child
    expect(children[2]._0.children).not.toBe(0); // not empty list
  });

  it("sends full root tree in third turn request body after partial patch and submit", () => {
    unresolvedFetch();
    const requestLog = [];
    const t = createRuntime({
      components: {
        container: () => null,
        text: () => null,
        submittable: () => null,
        broken: () => null,
      },
      request: vi.fn((context) => {
        requestLog.push(context);
        return { url: "/stream", headers: [], body: "{}" };
      }),
    });

    // Turn 1: bot sends full root tree
    const firstTurn = JSON.stringify({
      kind: "container",
      id: "root",
      children: [
        { kind: "container", id: "header-region", children: [{ kind: "text", id: "title", text_type: ["H1"], content: "Flight Booking" }] },
        { kind: "container", id: "search-form-region", children: [{ kind: "submittable", id: "search-form", value: [{ kind: "input", id: "origin", value: "" }] }] },
        { kind: "container", id: "results-region", children: [{ kind: "text", id: "placeholder", text_type: ["Paragraph"], content: "Search to see results" }] },
      ],
    });

    kick_off(t);
    on_chunk(t, firstTurn);
    on_done(t, 0);

    // Simulate user submitting the search form
    submit(t, {
      template_id: "search-form",
      values: list([
        { id: "origin", value: { TAG: 1, _0: "AKL" } },
      ]),
    });

    // Bot sends partial patch for results-region
    const secondTurn = JSON.stringify({
      kind: "container",
      id: "results-region",
      children: [
        { kind: "list", id: "flight-results", children: [
          { kind: "container", id: "flight-1", children: [
            { kind: "text", id: "flight-1-name", text_type: ["Paragraph"], content: "Air NZ 123" },
            { kind: "submittable", id: "select-flight-1", value: [] },
          ] },
        ] },
      ],
    });

    on_chunk(t, secondTurn);
    on_done(t, 0);

    // Simulate user selecting a flight
    submit(t, {
      template_id: "select-flight-1",
      values: list([]),
    });

    // Now check the request log
    expect(requestLog.length).toBe(3);

    // Turn 3 request should have 3 user messages
    const thirdRequest = requestLog[2];
    const messages = listToArray(thirdRequest.messages);
    expect(messages.length).toBe(3);

    // The latest message should contain the full root tree
    const latestMessage = messages[messages.length - 1];
    const treeJson = latestMessage.content.split("Current tree:\n\n")[1];
    const tree = JSON.parse(treeJson);

    expect(tree.kind).toBe("container");
    expect(tree.id).toBe("root");
    expect(tree.children.length).toBe(3);
    expect(tree.children[0].id).toBe("header-region");
    expect(tree.children[1].id).toBe("search-form-region");
    expect(tree.children[2].id).toBe("results-region");
  });
});
