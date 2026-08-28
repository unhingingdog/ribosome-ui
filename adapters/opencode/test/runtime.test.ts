import { describe, it, expect, vi } from "vitest";
import { Option } from "effect";
import { createRuntime, type PromptClient } from "../src/runtime.js";
import { createConfig, type InputEvent } from "../src/types.js";
import type { WebSocketLike } from "../src/transport.js";

class FakeWebSocket implements WebSocketLike {
  readyState = 0;
  bufferedAmount = 0;
  onopen: ((ev: Event) => void) | null = null;
  onmessage: ((ev: MessageEvent) => void) | null = null;
  onclose: ((ev: CloseEvent) => void) | null = null;
  onerror: ((ev: Event) => void) | null = null;
  sent: string[] = [];

  send(data: string): void {
    this.sent.push(data);
  }
  close(): void {
    this.readyState = 3;
  }
  fireOpen() {
    this.readyState = 1;
    this.onopen?.(new Event("open"));
  }
  fireMessage(data: string) {
    this.onmessage?.({ data } as MessageEvent);
  }
}

function makeFakePromptClient(): PromptClient & { promptCalls: Array<{ id: string; text: string; messageId?: string }>; sessionCreateCalls: number } {
  const promptCalls: Array<{ id: string; text: string; messageId?: string }> = [];
  const counts = { sessionCreate: 0 };
  const client = {
    session: {
      create: vi.fn(async () => {
        counts.sessionCreate++;
        return {
          data: { id: `oc-auto-${counts.sessionCreate}` },
          response: new Response(),
        };
      }),
      promptAsync: vi.fn(async (opts: any) => {
        promptCalls.push({
          id: opts.path.id,
          text: opts.body.parts[0].text,
          messageId: opts.body?.messageID,
        });
        return { response: new Response() };
      }),
    },
    promptCalls,
    get sessionCreateCalls() { return counts.sessionCreate; },
  };
  return client as any;
}

const config = createConfig("ws://127.0.0.1:8787", "start");

describe("runtime — integration", () => {
  it("forwards attach on ToolBefore for start tool", async () => {
    const fake = new FakeWebSocket();
    const pc = makeFakePromptClient();
    const rt = createRuntime(config, () => fake, pc);
    fake.fireOpen();

    rt.push({
      kind: "ToolBefore",
      ocId: "oc-1",
      tool: "start",
      callId: "call-1",
      nonce: Option.some("nonce-abc"),
    });
    rt.push({
      kind: "ToolAfter",
      ocId: "oc-1",
      tool: "start",
      callId: "call-1",
      output: JSON.stringify({ session_id: "rs-1", ui_nonce: "u1" }),
    });
    await new Promise((r) => setTimeout(r, 10));

    const attach = fake.sent.map((s) => JSON.parse(s)).find((m) => m.kind === "attach");
    expect(attach).toBeDefined();
    expect(attach.session_id).toBe("rs-1");
    expect(attach.harness_session_id).toBe("oc-1");
    expect(attach.nonce).toBe("nonce-abc");

    rt.shutdown();
  });

  it("streams deltas and completes generation", async () => {
    const fake = new FakeWebSocket();
    const pc = makeFakePromptClient();
    const rt = createRuntime(config, () => fake, pc);
    fake.fireOpen();

    // Kickoff
    rt.push({ kind: "ToolBefore", ocId: "oc-1", tool: "start", callId: "c1", nonce: Option.some("n1") });
    rt.push({
      kind: "ToolAfter",
      ocId: "oc-1",
      tool: "start",
      callId: "c1",
      output: JSON.stringify({ session_id: "rs-1", ui_nonce: "u1" }),
    });

    // Stream tokens
    const chunks = [`{"ki`, `nd":"`, `text"`, `,"id`, `":"t1"}`];
    for (const ch of chunks) {
      rt.push({
        kind: "PartUpdated",
        ocId: "oc-1",
        messageId: "msg-1",
        partType: "text",
        delta: Option.some(ch),
      });
    }

    // Flush
    rt.push({ kind: "FlushBatch", ocId: "oc-1" });
    await new Promise((r) => setTimeout(r, 10));

    const deltas = fake.sent.map((s) => JSON.parse(s)).filter((m) => m.kind === "delta");
    expect(deltas).toHaveLength(1);
    expect(deltas[0].content).toBe(`{"kind":"text","id":"t1"}`);
    expect(deltas[0].generation_id).toBe("msg-1");
    expect(deltas[0].seq).toBe(0);

    // Complete
    rt.push({ kind: "SessionIdle", ocId: "oc-1" });
    await new Promise((r) => setTimeout(r, 10));

    const completed = fake.sent.map((s) => JSON.parse(s)).find((m) => m.kind === "generation_completed");
    expect(completed).toBeDefined();
    expect(completed.generation_id).toBe("msg-1");

    rt.shutdown();
  });

  it("injects user turn via promptAsync", async () => {
    const fake = new FakeWebSocket();
    const pc = makeFakePromptClient();
    const rt = createRuntime(config, () => fake, pc);
    fake.fireOpen();

    // Kickoff + complete
    rt.push({ kind: "ToolBefore", ocId: "oc-1", tool: "start", callId: "c1", nonce: Option.some("n1") });
    rt.push({
      kind: "ToolAfter",
      ocId: "oc-1",
      tool: "start",
      callId: "c1",
      output: JSON.stringify({ session_id: "rs-1", ui_nonce: "u1" }),
    });
    rt.push({ kind: "SessionIdle", ocId: "oc-1" });
    await new Promise((r) => setTimeout(r, 10));

    // User turn from harness
    fake.fireMessage(JSON.stringify({
      kind: "user_turn",
      session_id: "rs-1",
      tree: '{"kind":"container"}',
      event: '{"type":"submit"}',
    }));
    await new Promise((r) => setTimeout(r, 10));

    expect(pc.promptCalls).toHaveLength(1);
    expect(pc.promptCalls[0].id).toBe("oc-1");
    expect(pc.promptCalls[0].text).toContain("[ribosome-tree]");

    rt.shutdown();
  });

  it("handles UI-initiated turn (unknown session)", async () => {
    const fake = new FakeWebSocket();
    const pc = makeFakePromptClient();
    const rt = createRuntime(config, () => fake, pc);
    fake.fireOpen();

    fake.fireMessage(JSON.stringify({
      kind: "user_turn",
      session_id: "rs-unknown",
      tree: '{"kind":"container"}',
      event: '{"type":"submit"}',
    }));
    await new Promise((r) => setTimeout(r, 50));

    expect(pc.sessionCreateCalls).toBeGreaterThanOrEqual(1);
    expect(pc.promptCalls).toHaveLength(1);
    expect(pc.promptCalls[0].text).toContain("[ribosome-tree]");

    rt.shutdown();
  });

  it("filters out injected message parts", async () => {
    const fake = new FakeWebSocket();
    const pc = makeFakePromptClient();
    const rt = createRuntime(config, () => fake, pc);
    fake.fireOpen();

    // Kickoff + complete
    rt.push({ kind: "ToolBefore", ocId: "oc-1", tool: "start", callId: "c1", nonce: Option.some("n1") });
    rt.push({
      kind: "ToolAfter",
      ocId: "oc-1",
      tool: "start",
      callId: "c1",
      output: JSON.stringify({ session_id: "rs-1", ui_nonce: "u1" }),
    });
    rt.push({ kind: "SessionIdle", ocId: "oc-1" });
    await new Promise((r) => setTimeout(r, 10));

    // User turn
    fake.fireMessage(JSON.stringify({
      kind: "user_turn",
      session_id: "rs-1",
      tree: '{"kind":"container"}',
      event: '{"type":"submit"}',
    }));
    await new Promise((r) => setTimeout(r, 10));

    // The messageId was pre-recorded by the reduce function
    const injectedMsgId = pc.promptCalls[0].messageId!;

    // Simulate echo of user prompt text (should be filtered)
    const beforeSent = fake.sent.length;
    rt.push({
      kind: "PartUpdated",
      ocId: "oc-1",
      messageId: injectedMsgId,
      partType: "text",
      delta: Option.some("user prompt text that should be filtered"),
    });
    await new Promise((r) => setTimeout(r, 10));

    // No new delta messages should have been sent
    const newDeltas = fake.sent.slice(beforeSent).map((s) => JSON.parse(s)).filter((m) => m.kind === "delta");
    expect(newDeltas).toHaveLength(0);

    // Now model output with a different messageId (should be forwarded)
    rt.push({
      kind: "PartUpdated",
      ocId: "oc-1",
      messageId: "msg-2",
      partType: "text",
      delta: Option.some(`{"kind":"text","id":"r1"}`),
    });
    rt.push({ kind: "FlushBatch", ocId: "oc-1" });
    await new Promise((r) => setTimeout(r, 10));

    const modelDeltas = fake.sent.slice(beforeSent).map((s) => JSON.parse(s)).filter((m) => m.kind === "delta");
    expect(modelDeltas).toHaveLength(1);
    expect(modelDeltas[0].content).toBe(`{"kind":"text","id":"r1"}`);

    rt.shutdown();
  });
});
