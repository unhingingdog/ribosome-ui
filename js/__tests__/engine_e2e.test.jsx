// @vitest-environment jsdom

import React from "react";
import { cleanup, fireEvent, screen, waitFor } from "@testing-library/react";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { create } from "../output/engine/Engine.js";

const list = (items) =>
  items.reduceRight((tl, hd) => ({ hd, tl }), 0);

const listToArray = (items) => {
  const result = [];
  let current = items;

  while (current !== 0) {
    result.push(current.hd);
    current = current.tl;
  }

  return result;
};

const encode = (value) => new TextEncoder().encode(value);

const createControlledStream = () => {
  const pendingReads = [];
  const queuedReads = [];

  const enqueue = (result) => {
    const resolve = pendingReads.shift();

    if (resolve === undefined) {
      queuedReads.push(result);
    } else {
      resolve(result);
    }
  };

  return {
    response: {
      ok: true,
      status: 200,
      statusText: "OK",
      body: {
        getReader: () => ({
          read: vi.fn(() => {
            const queued = queuedReads.shift();

            if (queued !== undefined) {
              return Promise.resolve(queued);
            }

            return new Promise((resolve) => pendingReads.push(resolve));
          }),
        }),
      },
    },
    push: (chunk) => enqueue({ done_: false, value: encode(chunk) }),
    close: () => enqueue({ done_: true }),
  };
};

const chunks = {
  one: '{"kind":"container","id":"profile-container","children":[{"kind"',
  two: ':"text","id":"profile-heading","text_type":["H1"],"content":"Profile"',
  three:
    ',"content":"Profile setup"},{"kind":"submittable","id":"profile-form","value":[{"kind":"input","id":"name","value":["String",""]}',
  four: ',{"kind":"input","id":"color","value":["String",""]}]}',
};

const firstTurnJson = chunks.one + chunks.two + chunks.three + chunks.four;

const components = {
  input: undefined,
  image: undefined,
  container: ({ children }) => <section>{children}</section>,
  broken: ({ children }) => <div role="alert">{children}</div>,
  text: ({ text_type, content }) =>
    text_type === 1 ? <h1>{content}</h1> : <p>{content}</p>,
  submittable: ({ id, value, on_submit }) => (
    <form
      aria-label={id}
      onSubmit={(event) => {
        event.preventDefault();
        const data = new FormData(event.currentTarget);

        on_submit({
          template_id: id,
          values: list(
            listToArray(value).map((input) => ({
              id: input.id,
              value: { TAG: 1, _0: data.get(input.id) },
            })),
          ),
        });
      }}
    >
      {listToArray(value).map((input) => (
        <label key={input.id}>
          {input.id}
          <input name={input.id} defaultValue="" />
        </label>
      ))}
      <button type="submit">Save profile</button>
    </form>
  ),
};

describe.sequential("Engine end-to-end React streaming flow", () => {
  let stream;
  let callbacks;
  let request;

  beforeAll(() => {
    document.body.innerHTML = '<div id="root"></div>';
    stream = createControlledStream();
    callbacks = {
      on_submit: vi.fn(),
      on_message_complete: vi.fn(),
      on_error: vi.fn(),
    };
    request = vi.fn((context) => ({
      url: "/stream",
      headers: [],
      body: JSON.stringify({
        system_prompt: context.system_prompt,
        messages: listToArray(context.messages),
      }),
    }));

    vi.stubGlobal(
      "fetch",
      vi.fn()
        .mockResolvedValueOnce(stream.response)
        .mockImplementationOnce(() => new Promise(() => {})),
    );

    create({
      root: { TAG: 1, _0: "root" },
      components,
      templates: 0,
      assets: 0,
      goal_prompt: "Collect profile details",
      request,
      stream_adapter: (payload) => ({ TAG: 0, _0: payload }),
      callbacks,
    });
  });

  afterAll(() => {
    cleanup();
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it("chunk 1 is not closable, so nothing renders", async () => {
    stream.push(`data: ${chunks.one}`);

    await waitFor(() => {
      expect(screen.queryByRole("heading")).toBeNull();
      expect(screen.queryByRole("form")).toBeNull();
    });
  });

  it("chunk 2 renders the heading with partial content", async () => {
    stream.push(`${chunks.two}\n`);

    await screen.findByRole("heading", { name: "Profile" });
    expect(screen.queryByRole("form", { name: "profile-form" })).toBeNull();
  });

  it("chunk 3 renders the completed heading and first form field", async () => {
    stream.push(`data: ${chunks.three}\n`);

    await screen.findByRole("heading", { name: "Profile setup" });
    await screen.findByRole("form", { name: "profile-form" });
    expect(screen.getByLabelText("name")).not.toBeNull();
    expect(screen.queryByLabelText("color")).toBeNull();
  });

  it("chunk 4 renders the full template", async () => {
    stream.push(`data: ${chunks.four}\n`);
    stream.close();

    await screen.findByLabelText("color");
    expect(screen.getByRole("heading", { name: "Profile setup" })).not.toBeNull();
    expect(screen.getByLabelText("name")).not.toBeNull();
    expect(screen.getByLabelText("color")).not.toBeNull();
    await waitFor(() => expect(callbacks.on_message_complete).toHaveBeenCalledTimes(1));
  });

  it("submits the form and sends the submitted values in the next request body", async () => {
    fireEvent.change(screen.getByLabelText("name"), { target: { value: "Ada" } });
    fireEvent.change(screen.getByLabelText("color"), { target: { value: "blue" } });
    fireEvent.click(screen.getByRole("button", { name: "Save profile" }));

    await waitFor(() => expect(fetch).toHaveBeenCalledTimes(2));

    const secondFetchBody = JSON.parse(fetch.mock.calls[1][1].body);
    const submittedMessage = JSON.parse(secondFetchBody.messages.at(-1).content);

    expect(submittedMessage).toEqual({
      template_id: "profile-form",
      values: [
        { id: "name", value: ["SubmittedString", "Ada"] },
        { id: "color", value: ["SubmittedString", "blue"] },
      ],
    });
    expect(secondFetchBody.messages).toMatchObject([
      { role: 0, content: "Collect profile details" },
      { role: 1, content: firstTurnJson },
      { role: 0 },
    ]);
    expect(callbacks.on_submit).toHaveBeenCalledTimes(1);
    expect(callbacks.on_error).not.toHaveBeenCalled();
  });
});
