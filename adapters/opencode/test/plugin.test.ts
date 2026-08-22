import { describe, it, expect, vi } from "vitest";
import {
  createAdapterContext,
  createHooks,
} from "../src/plugin.js";
import { createConfig } from "../src/config.js";
import type { WebSocketLike } from "../src/connection.js";

class FakeWebSocket implements WebSocketLike {
  readyState = 0;
  onopen: ((ev: Event) => void) | null = null;
  onmessage: ((ev: MessageEvent) => void) | null = null;
  onclose: ((ev: CloseEvent) => void) | null = null;
  onerror: ((ev: Event) => void) | null = null;
  sent: string[] = [];
  closed = false;

  send(data: string): void {
    this.sent.push(data);
  }

  close(code?: number, reason?: string): void {
    this.closed = true;
    this.readyState = 3;
  }

  fireOpen() {
    this.readyState = 1;
    if (this.onopen) this.onopen(new Event("open"));
  }
}

function makeCtx() {
  const fake = new FakeWebSocket();
  const ctx = createAdapterContext(
    createConfig("ws://127.0.0.1:8787", "start"),
    () => fake,
  );
  return { ctx, fake };
}

describe("plugin hooks — kickoff correlation", () => {
  it("injects nonce and harness_session_id in tool.execute.before", async () => {
    const { ctx } = makeCtx();
    const hooks = createHooks(ctx);

    const output: { args: Record<string, unknown> } = { args: {} };
    await hooks["tool.execute.before"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1" },
      output,
    );

    expect(output.args._nonce).toBeDefined();
    expect(output.args._harness_session_id).toBe("oc-1");
    expect(ctx.kickoff.pendingCount).toBe(1);
  });

  it("ignores non-start tools in tool.execute.before", async () => {
    const { ctx } = makeCtx();
    const hooks = createHooks(ctx);

    const output: { args: Record<string, unknown> } = { args: {} };
    await hooks["tool.execute.before"]!(
      { tool: "other_tool", sessionID: "oc-1", callID: "call-1" },
      output,
    );

    expect(output.args._nonce).toBeUndefined();
    expect(ctx.kickoff.pendingCount).toBe(0);
  });

  it("activates and sends harness attach on successful tool.execute.after", async () => {
    const { ctx, fake } = makeCtx();
    const hooks = createHooks(ctx);

    const beforeOutput: { args: Record<string, unknown> } = { args: {} };
    await hooks["tool.execute.before"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1" },
      beforeOutput,
    );

    const toolResult = JSON.stringify({
      session_id: "rs-1",
      ui_nonce: "ui-nonce-abc",
      mode: "ui",
    });
    await hooks["tool.execute.after"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1", args: beforeOutput.args },
      { title: "", output: toolResult, metadata: {} },
    );

    fake.fireOpen();
    expect(ctx.kickoff.activeCount).toBe(1);
    expect(fake.sent.length).toBeGreaterThanOrEqual(1);

    const attach = JSON.parse(fake.sent[0]);
    expect(attach.kind).toBe("attach");
    expect(attach.session_id).toBe("rs-1");
    expect(attach.harness_session_id).toBe("oc-1");
    expect(attach.nonce).toMatch(/^oc-/);
  });

  it("clears pending on failed tool.execute.after (non-JSON output)", async () => {
    const { ctx } = makeCtx();
    const hooks = createHooks(ctx);

    await hooks["tool.execute.before"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1" },
      { args: {} },
    );
    expect(ctx.kickoff.pendingCount).toBe(1);

    await hooks["tool.execute.after"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1", args: {} },
      { title: "error", output: "something went wrong", metadata: {} },
    );

    expect(ctx.kickoff.pendingCount).toBe(0);
    expect(ctx.kickoff.activeCount).toBe(0);
  });

  it("parallel sessions get distinct nonces and channels", async () => {
    const { ctx, fake } = makeCtx();
    const hooks = createHooks(ctx);

    const out1: { args: Record<string, unknown> } = { args: {} };
    const out2: { args: Record<string, unknown> } = { args: {} };
    await hooks["tool.execute.before"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1" },
      out1,
    );
    await hooks["tool.execute.before"]!(
      { tool: "start", sessionID: "oc-2", callID: "call-2" },
      out2,
    );

    expect(out1.args._nonce).not.toBe(out2.args._nonce);
    expect(out1.args._harness_session_id).toBe("oc-1");
    expect(out2.args._harness_session_id).toBe("oc-2");

    await hooks["tool.execute.after"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1", args: out1.args },
      {
        title: "",
        output: JSON.stringify({ session_id: "rs-1", ui_nonce: "u1" }),
        metadata: {},
      },
    );
    await hooks["tool.execute.after"]!(
      { tool: "start", sessionID: "oc-2", callID: "call-2", args: out2.args },
      {
        title: "",
        output: JSON.stringify({ session_id: "rs-2", ui_nonce: "u2" }),
        metadata: {},
      },
    );

    fake.fireOpen();
    expect(ctx.kickoff.activeCount).toBe(2);
    expect(fake.sent.length).toBe(2);

    const attach1 = JSON.parse(fake.sent[0]);
    const attach2 = JSON.parse(fake.sent[1]);
    expect(attach1.session_id).toBe("rs-1");
    expect(attach2.session_id).toBe("rs-2");
    expect(attach1.nonce).not.toBe(attach2.nonce);
    expect(attach1.harness_session_id).toBe("oc-1");
    expect(attach2.harness_session_id).toBe("oc-2");
  });

  it("clears active session on session.error event", async () => {
    const { ctx, fake } = makeCtx();
    const hooks = createHooks(ctx);

    await hooks["tool.execute.before"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1" },
      { args: {} },
    );
    await hooks["tool.execute.after"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1", args: {} },
      {
        title: "",
        output: JSON.stringify({ session_id: "rs-1", ui_nonce: "u1" }),
        metadata: {},
      },
    );
    fake.fireOpen();
    expect(ctx.kickoff.activeCount).toBe(1);

    await hooks.event!({
      event: {
        type: "session.error",
        properties: { sessionID: "oc-1" },
      } as any,
    });

    expect(ctx.kickoff.activeCount).toBe(0);
  });

  it("marks kickoff complete on session.idle event", async () => {
    const { ctx, fake } = makeCtx();
    const hooks = createHooks(ctx);

    await hooks["tool.execute.before"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1" },
      { args: {} },
    );
    await hooks["tool.execute.after"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1", args: {} },
      {
        title: "",
        output: JSON.stringify({ session_id: "rs-1", ui_nonce: "u1" }),
        metadata: {},
      },
    );
    fake.fireOpen();

    await hooks.event!({
      event: {
        type: "session.idle",
        properties: { sessionID: "oc-1" },
      } as any,
    });

    const session = ctx.sessions.get("oc-1");
    expect(session?.pendingKickoff).toBe(false);
  });

  it("disposes harness connection", async () => {
    const { ctx, fake } = makeCtx();
    const hooks = createHooks(ctx);

    await hooks["tool.execute.before"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1" },
      { args: {} },
    );
    await hooks["tool.execute.after"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1", args: {} },
      {
        title: "",
        output: JSON.stringify({ session_id: "rs-1", ui_nonce: "u1" }),
        metadata: {},
      },
    );
    fake.fireOpen();

    await hooks.dispose!();
    expect(fake.closed).toBe(true);
    expect(ctx.harnessConn).toBeNull();
  });

  it("forwards five assistant deltas as five harness delta messages", async () => {
    const { ctx, fake } = makeCtx();
    const hooks = createHooks(ctx);

    await hooks["tool.execute.before"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1" },
      { args: {} },
    );
    await hooks["tool.execute.after"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1", args: {} },
      {
        title: "",
        output: JSON.stringify({ session_id: "rs-1", ui_nonce: "u1" }),
        metadata: {},
      },
    );
    fake.fireOpen();

    const deltaEvents = [
      { part: { sessionID: "oc-1", messageID: "msg-1", type: "text", id: "p1" }, delta: "H" },
      { part: { sessionID: "oc-1", messageID: "msg-1", type: "text", id: "p1" }, delta: "e" },
      { part: { sessionID: "oc-1", messageID: "msg-1", type: "text", id: "p1" }, delta: "l" },
      { part: { sessionID: "oc-1", messageID: "msg-1", type: "text", id: "p1" }, delta: "l" },
      { part: { sessionID: "oc-1", messageID: "msg-1", type: "text", id: "p1" }, delta: "o" },
    ];

    for (const ev of deltaEvents) {
      await hooks.event!({
        event: { type: "message.part.updated", properties: ev } as any,
      });
    }

    const deltaMsgs = fake.sent
      .slice(1)
      .map((s) => JSON.parse(s))
      .filter((m) => m.kind === "delta");

    expect(deltaMsgs.length).toBe(5);
    expect(deltaMsgs.map((m) => m.seq)).toEqual([0, 1, 2, 3, 4]);
    expect(deltaMsgs.map((m) => m.content)).toEqual(["H", "e", "l", "l", "o"]);
    expect(deltaMsgs.every((m) => m.generation_id === "msg-1")).toBe(true);
  });

  it("completes generation on session.idle after deltas", async () => {
    const { ctx, fake } = makeCtx();
    const hooks = createHooks(ctx);

    await hooks["tool.execute.before"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1" },
      { args: {} },
    );
    await hooks["tool.execute.after"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1", args: {} },
      {
        title: "",
        output: JSON.stringify({ session_id: "rs-1", ui_nonce: "u1" }),
        metadata: {},
      },
    );
    fake.fireOpen();

    await hooks.event!({
      event: {
        type: "message.part.updated",
        properties: { part: { sessionID: "oc-1", messageID: "msg-1", type: "text", id: "p1" }, delta: "Hi" },
      } as any,
    });
    await hooks.event!({
      event: { type: "session.idle", properties: { sessionID: "oc-1" } } as any,
    });

    const sent = fake.sent.map((s) => JSON.parse(s));
    const completed = sent.find((m) => m.kind === "generation_completed");
    expect(completed).toBeDefined();
    expect(completed.generation_id).toBe("msg-1");
  });

  it("reports generation failure on session.error", async () => {
    const { ctx, fake } = makeCtx();
    const hooks = createHooks(ctx);

    await hooks["tool.execute.before"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1" },
      { args: {} },
    );
    await hooks["tool.execute.after"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1", args: {} },
      {
        title: "",
        output: JSON.stringify({ session_id: "rs-1", ui_nonce: "u1" }),
        metadata: {},
      },
    );
    fake.fireOpen();

    await hooks.event!({
      event: {
        type: "message.part.updated",
        properties: { part: { sessionID: "oc-1", messageID: "msg-1", type: "text", id: "p1" }, delta: "Hi" },
      } as any,
    });
    await hooks.event!({
      event: {
        type: "session.error",
        properties: { sessionID: "oc-1", error: { message: "timeout" } },
      } as any,
    });

    const sent = fake.sent.map((s) => JSON.parse(s));
    const failed = sent.find((m) => m.kind === "generation_failed");
    expect(failed).toBeDefined();
    expect(failed.generation_id).toBe("msg-1");
    expect(failed.reason).toContain("timeout");
  });

  it("injects user_turn as complete submission via promptAsync", async () => {
    const { ctx, fake } = makeCtx();
    const hooks = createHooks(ctx);

    const promptCalls: Array<{ id: string; text: string }> = [];
    ctx.promptClient = {
      promptAsync: vi.fn(async (body: any) => {
        promptCalls.push({
          id: body.path.id,
          text: body.body.parts[0].text,
        });
        return {};
      }),
    };

    await hooks["tool.execute.before"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1" },
      { args: {} },
    );
    await hooks["tool.execute.after"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1", args: {} },
      {
        title: "",
        output: JSON.stringify({ session_id: "rs-1", ui_nonce: "u1" }),
        metadata: {},
      },
    );
    fake.fireOpen();

    const userTurn = JSON.stringify({
      kind: "user_turn",
      session_id: "rs-1",
      tree: '{"type":"column"}',
      event: '{"type":"submit","target":"form1"}',
    });
    fake.onmessage!({ data: userTurn } as MessageEvent);
    await new Promise((r) => setTimeout(r, 0));

    expect(promptCalls.length).toBe(1);
    expect(promptCalls[0].id).toBe("oc-1");
    expect(promptCalls[0].text).toContain("[ribosome-tree]");
    expect(promptCalls[0].text).toContain("[ribosome-event]");
  });

  it("queues at most one submission while busy, flushes on idle", async () => {
    const { ctx, fake } = makeCtx();
    const hooks = createHooks(ctx);

    const promptCalls: Array<{ id: string; text: string }> = [];
    ctx.promptClient = {
      promptAsync: vi.fn(async (body: any) => {
        promptCalls.push({
          id: body.path.id,
          text: body.body.parts[0].text,
        });
        return {};
      }),
    };

    await hooks["tool.execute.before"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1" },
      { args: {} },
    );
    await hooks["tool.execute.after"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1", args: {} },
      {
        title: "",
        output: JSON.stringify({ session_id: "rs-1", ui_nonce: "u1" }),
        metadata: {},
      },
    );
    fake.fireOpen();

    const userTurn = JSON.stringify({
      kind: "user_turn",
      session_id: "rs-1",
      tree: '{"type":"column"}',
      event: '{"type":"submit","target":"form1"}',
    });
    fake.onmessage!({ data: userTurn } as MessageEvent);
    await new Promise((r) => setTimeout(r, 0));
    fake.onmessage!({ data: userTurn } as MessageEvent);
    await new Promise((r) => setTimeout(r, 0));

    expect(promptCalls.length).toBe(1);
    expect(ctx.submission.queuedCount).toBe(1);

    await hooks.event!({
      event: { type: "session.idle", properties: { sessionID: "oc-1" } } as any,
    });
    await new Promise((r) => setTimeout(r, 0));

    expect(promptCalls.length).toBe(2);
    expect(ctx.submission.queuedCount).toBe(0);
  });

  it("rejects user_turn for unknown sessions", async () => {
    const { ctx, fake } = makeCtx();
    const hooks = createHooks(ctx);

    const promptCalls: Array<{ id: string; text: string }> = [];
    ctx.promptClient = {
      promptAsync: vi.fn(async (body: any) => {
        promptCalls.push({
          id: body.path.id,
          text: body.body.parts[0].text,
        });
        return {};
      }),
    };

    await hooks["tool.execute.before"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1" },
      { args: {} },
    );
    await hooks["tool.execute.after"]!(
      { tool: "start", sessionID: "oc-1", callID: "call-1", args: {} },
      {
        title: "",
        output: JSON.stringify({ session_id: "rs-1", ui_nonce: "u1" }),
        metadata: {},
      },
    );
    fake.fireOpen();

    const userTurn = JSON.stringify({
      kind: "user_turn",
      session_id: "rs-unknown",
      tree: '{"type":"column"}',
      event: '{"type":"submit"}',
    });
    fake.onmessage!({ data: userTurn } as MessageEvent);
    await new Promise((r) => setTimeout(r, 0));

    expect(promptCalls.length).toBe(0);
  });
});
