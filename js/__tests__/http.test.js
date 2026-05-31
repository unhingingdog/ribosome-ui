import { afterEach, describe, expect, it, vi } from "vitest";
import { post } from "../output/engine/Http.js";

const encode = (value) => new TextEncoder().encode(value);

const reader = (reads) => {
  let index = 0;
  return {
    read: vi.fn(() => Promise.resolve(reads[index++] ?? { done_: true })),
  };
};

describe("Http.post", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("reports Complete after the stream finishes", async () => {
    const onChunk = vi.fn();
    const onDone = vi.fn();
    const onError = vi.fn();
    const bodyReader = reader([
      { done_: false, value: encode("data: hello\n") },
      { done_: true },
    ]);

    vi.stubGlobal(
      "fetch",
      vi.fn(() =>
        Promise.resolve({
          ok: true,
          status: 200,
          statusText: "OK",
          body: { getReader: () => bodyReader },
        }),
      ),
    );

    await post("/stream", [], "{}", onChunk, onDone, onError);

    expect(onChunk).toHaveBeenCalledWith("hello");
    expect(onDone).toHaveBeenCalledWith(0);
    expect(onError).not.toHaveBeenCalled();
  });

  it("reports Failed and onError when fetch rejects", async () => {
    const onDone = vi.fn();
    const onError = vi.fn();

    vi.stubGlobal(
      "fetch",
      vi.fn(() => Promise.reject(new Error("network failed"))),
    );

    await post("/stream", [], "{}", vi.fn(), onDone, onError);

    expect(onDone).toHaveBeenCalledWith({ TAG: 0, _0: "network failed" });
    expect(onError).toHaveBeenCalledWith("network failed");
  });
});
