import { afterEach, describe, expect, it, vi } from "vitest";
import {
  create_runtime,
  kick_off,
  on_chunk,
  on_done,
  reset_turn,
  run_turn,
  set_error,
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
    expect(t.last_template).toBeUndefined();
    expect(t.last_error).toBeUndefined();
  });

  it("run_turn appends user history and starts the configured request", () => {
    unresolvedFetch();
    const t = createRuntime();

    run_turn(t, "user submitted data", "current interaction");

    expect(listToArray(t.history)).toMatchObject([
      { role: 0, content: "user submitted data" },
    ]);
    expect(t.config.request).toHaveBeenCalledOnce();
    expect(fetch).toHaveBeenCalledWith(
      "/stream",
      expect.objectContaining({ method: "POST", body: "{}" }),
    );
  });

  it("processes a streamed template and completes assistant history", () => {
    unresolvedFetch();
    const t = createRuntime();
    const templateJson =
      '{"kind":"text","id":"intro","text_type":["Paragraph"],"content":"Hello"}';

    kick_off(t);
    on_chunk(t, templateJson);
    on_done(t, 0);

    expect(t.last_template).toMatchObject({ TAG: 2, _0: { id: "intro" } });
    expect(listToArray(t.history)).toMatchObject([
      { role: 0, content: "Render the first UI" },
      { role: 1, content: templateJson },
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
      { role: 0, content: "Render the first UI" },
      { role: 1, content: firstTemplate },
      { role: 0 },
      { role: 1, content: secondTemplate },
      { role: 0 },
      { role: 1, content: finalTemplate },
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
      { role: 0, content: "Render the first UI" },
      { role: 1, content: firstTemplate },
      { role: 0 },
    ]);
  });
});
