import { describe, it, expect } from "vitest";
import { create_processor, feed } from "./output/telomere/Processor.js";

describe("Processor — incremental streaming", () => {
  it("emits completion once an open string value can be capped", () => {
    let ps = create_processor();

    let [out, ps1] = feed(ps, '{"key":');
    expect(out).toBe(0); // Pending

    let [out2] = feed(ps1, '"val');
    expect(out2.TAG).toBe(0); // Completion
    expect(out2._0).toBe('"}'); // close string and object
  });

  it("completion shrinks as more structure arrives", () => {
    let ps = create_processor();

    let [out1, ps1] = feed(ps, '{"a":[');
    expect(out1.TAG).toBe(0);
    expect(out1._0).toBe("]}");

    let [out2, ps2] = feed(ps1, '{"b":1');
    expect(out2.TAG).toBe(0);
    expect(out2._0).toBe("}]}");

    let [out3, ps3] = feed(ps2, "}");
    expect(out3.TAG).toBe(0);
    expect(out3._0).toBe("]}");

    let [out4] = feed(ps3, "]");
    expect(out4.TAG).toBe(0);
    expect(out4._0).toBe("}");
  });

  it("emits Corrupted on mismatched bracket and poisons subsequent feeds", () => {
    let ps = create_processor();

    let [, ps1] = feed(ps, '{"a":1');
    let [out2, ps2] = feed(ps1, "]"); // mismatch — object closed with bracket
    expect(out2).toBe(1); // Corrupted

    let [out3] = feed(ps2, '{"b":2}');
    expect(out3).toBe(1); // Corrupted — poisoned state fast-paths
  });

  it("handles a complete well-formed object with empty completion", () => {
    let ps = create_processor();

    let [, ps1] = feed(ps, '{"name"');
    let [, ps2] = feed(ps1, ':"Alice"');
    let [out3] = feed(ps2, "}");
    expect(out3.TAG).toBe(0); // Completion
    expect(out3._0).toBe("");
  });
});
