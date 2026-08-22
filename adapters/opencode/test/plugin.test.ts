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
});
