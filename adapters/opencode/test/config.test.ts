import { describe, it, expect } from "vitest";
import { createConfig } from "../src/config.js";

describe("config", () => {
  it("creates with default tool name", () => {
    const c = createConfig("ws://127.0.0.1:8787");
    expect(c.serverUrl).toBe("ws://127.0.0.1:8787");
    expect(c.mcpToolName).toBe("start");
  });

  it("creates with custom tool name", () => {
    const c = createConfig("ws://localhost:9000", "ribosome_start");
    expect(c.serverUrl).toBe("ws://localhost:9000");
    expect(c.mcpToolName).toBe("ribosome_start");
  });
});
