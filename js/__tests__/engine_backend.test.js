import { describe, expect, it } from "vitest";

import { handle_chunk } from "../output/engine/EngineBackend.js";
import { create_processor } from "../output/telomere/Processor.js";

describe("EngineBackend streaming", () => {
  it("keeps soft parse failures pending until more bytes produce a renderable template", () => {
    let processor = create_processor();

    const first = handle_chunk(
      '{"kind":"container","id":"root","children":[{"kind":"text","id":"title","text_type":"H1"',
      processor,
    );

    expect(first.TAG).toBe(0); // Pending, not Failed
    processor = first._0;

    const second = handle_chunk(',"value":"Hello streaming"', processor);

    expect(second.TAG).toBe(1); // Parsed
    expect(second._0[0].TAG).toBe(4); // Container
  });
});
