import { describe, it, expect, beforeAll, afterAll, beforeEach } from "vitest";
import { spawn, type ChildProcess } from "node:child_process";
import { resolve } from "node:path";
import { Option } from "effect";
import { createRuntime, type PromptClient } from "../src/runtime.js";
import { createConfig } from "../src/types.js";
import type { WebSocketLike } from "../src/transport.js";

const REPO_ROOT = resolve(__dirname, "../../..");
const TEST_PORT = 18787;
const SERVER_URL = `ws://127.0.0.1:${TEST_PORT}`;
const SERVER_BIN = resolve(REPO_ROOT, "_build/default/ribosome-server/bin/main.exe");
const SKILL_ROOT = resolve(REPO_ROOT, "skills");
const HEALTH_URL = `http://127.0.0.1:${TEST_PORT}/health`;

const RECONCILE_WAIT_MS = 300;
const STARTUP_TIMEOUT_MS = 10000;
const HEALTH_POLL_MS = 100;

class RawWebSocket implements WebSocketLike {
  readyState = 0;
  bufferedAmount = 0;
  onopen: ((ev: Event) => void) | null = null;
  onmessage: ((ev: MessageEvent) => void) | null = null;
  onclose: ((ev: CloseEvent) => void) | null = null;
  onerror: ((ev: Event) => void) | null = null;
  private ws: WebSocket;

  constructor(url: string) {
    this.ws = new WebSocket(url);
    this.ws.onopen = (ev) => { this.readyState = 1; this.onopen?.(ev); };
    this.ws.onmessage = (ev) => { this.onmessage?.(ev); };
    this.ws.onclose = (ev) => { this.readyState = 3; this.onclose?.(ev); };
    this.ws.onerror = (ev) => { this.onerror?.(ev); };
  }

  send(data: string): void { this.ws.send(data); }
  close(code?: number, reason?: string): void { this.ws.close(code, reason); }
}

function makeFakePromptClient(): PromptClient & {
  promptCalls: Array<{ id: string; text: string; messageId?: string }>;
  sessionCreateCount: number;
} {
  const promptCalls: Array<{ id: string; text: string; messageId?: string }> = [];
  const counts = { create: 0 };
  return {
    session: {
      create: async () => {
        counts.create++;
        return { data: { id: `oc-auto-${counts.create}` }, response: new Response() };
      },
      promptAsync: async (opts: any) => {
        promptCalls.push({
          id: opts.path.id,
          text: opts.body.parts[0].text,
          messageId: opts.body?.messageID,
        });
        return { response: new Response() };
      },
    },
    promptCalls,
    get sessionCreateCount() { return counts.create; },
  } as any;
}

function waitFor(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

async function waitForHealth(timeoutMs: number): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const resp = await fetch(HEALTH_URL);
      if (resp.ok) return;
    } catch {
      // server not ready yet
    }
    await waitFor(HEALTH_POLL_MS);
  }
  throw new Error(`server did not become healthy within ${timeoutMs}ms`);
}

type InboxMsg = { kind: string; [k: string]: unknown };

async function waitForNthMessage(
  inbox: InboxMsg[],
  kind: string,
  n: number,
  timeoutMs = 5000,
): Promise<InboxMsg> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const matches = inbox.filter((m) => m.kind === kind);
    if (matches.length >= n) return matches[n - 1];
    await waitFor(50);
  }
  throw new Error(`did not receive ${n}th ${kind} within ${timeoutMs}ms`);
}

function makeUiClient(sessionId: string): { ws: RawWebSocket; inbox: InboxMsg[] } {
  const inbox: InboxMsg[] = [];
  const ws = new RawWebSocket(`${SERVER_URL}/v1/ui`);
  ws.onmessage = (ev) => {
    try { inbox.push(JSON.parse(String(ev.data))); } catch { /* ignore */ }
  };
  return { ws, inbox };
}

function sendUiAttach(ws: RawWebSocket, sessionId: string): void {
  ws.send(JSON.stringify({ kind: "attach", session_id: sessionId }));
}

function sendUiEvent(ws: RawWebSocket, sessionId: string, revision: number, eventId: string, targetId: string, componentKind: string, value?: string): void {
  const msg: Record<string, unknown> = {
    kind: "component_event",
    session_id: sessionId,
    revision,
    event_id: eventId,
    target_id: targetId,
    component_kind: componentKind,
  };
  if (value !== undefined) msg.value = value;
  ws.send(JSON.stringify(msg));
}

const HOME_TEMPLATE_TEXT = `{"kind":"container","id":"home-root","direction":"Vertical","children":[{"kind":"text","id":"home-title","text_type":"H1","value":"Ribosome"},{"kind":"submittable","id":"home-form","value":[{"kind":"input","id":"home-input","value":""}],"button":{"kind":"button","id":"home-submit","label":"Submit","action":"Submit"}}]}`;

describe("integration — adapter ↔ ribosome-server", () => {
  let serverProc: ChildProcess | null = null;
  let rt: ReturnType<typeof createRuntime> | null = null;
  let pc: ReturnType<typeof makeFakePromptClient>;

  beforeAll(async () => {
    const childEnv = { ...process.env, RIBOSOME_DEBUG: process.env.RIBOSOME_DEBUG ?? "1" };
    serverProc = spawn(SERVER_BIN, ["--port", String(TEST_PORT), "--skill-root", SKILL_ROOT], {
      stdio: ["pipe", "pipe", "pipe"],
      cwd: REPO_ROOT,
      env: childEnv,
    });

    serverProc.stdout?.on("data", (data) => {
      if (process.env.RIBOSOME_INTEGRATION_DEBUG) {
        process.stderr.write(`[server:out] ${data}`);
      }
    });
    serverProc.stderr?.on("data", (data) => {
      if (process.env.RIBOSOME_INTEGRATION_DEBUG) {
        process.stderr.write(`[server:err] ${data}`);
      }
    });

    await waitForHealth(STARTUP_TIMEOUT_MS);
  });

  afterAll(() => {
    rt?.shutdown();
    if (serverProc) {
      serverProc.kill("SIGTERM");
      serverProc = null;
    }
  });

  beforeEach(() => {
    pc = makeFakePromptClient();
    const config = createConfig(SERVER_URL, "start");
    rt = createRuntime(config, (url) => new RawWebSocket(url), pc);
  });

  it("UI-initiated: UI attach → submit → adapter creates session → model streams → UI updates", async () => {
    const ribId = "rs-int-1";

    const { ws: uiWs, inbox } = makeUiClient(ribId);
    await waitFor(200);
    sendUiAttach(uiWs, ribId);

    const sessionState = await waitForNthMessage(inbox, "session_state", 1);
    expect(sessionState.session_id).toBe(ribId);
    expect(sessionState.revision).toBe(1);

    sendUiEvent(uiWs, ribId, 1, "evt-1", "home-form", "submit");

    await waitFor(1000);
    expect(pc.promptCalls.length).toBeGreaterThanOrEqual(1);
    expect(pc.promptCalls[0].text).toContain("[ribosome-tree]");

    const modelJson = `{"kind":"container","id":"home-root","direction":"Vertical","children":[{"kind":"text","id":"home-title","text_type":"H2","value":"Hello!"},{"kind":"submittable","id":"home-form","value":[{"kind":"input","id":"home-input","value":""}],"button":{"kind":"button","id":"home-submit","label":"Submit","action":"Submit"}}]}`;

    for (let i = 0; i < modelJson.length; i++) {
      rt!.push({
        kind: "PartUpdated",
        ocId: pc.promptCalls[0].id,
        messageId: "msg-model-1",
        partType: "text",
        delta: Option.some(modelJson[i]),
      });
    }
    rt!.push({ kind: "FlushBatch", ocId: pc.promptCalls[0].id });
    await waitFor(RECONCILE_WAIT_MS);

    const templateUpdate = await waitForNthMessage(inbox, "template_update", 2);
    expect(templateUpdate.session_id).toBe(ribId);
    const tree = JSON.parse(templateUpdate.tree as string);
    expect(tree.kind).toBe("container");
    expect(tree.children[0].value).toBe("Hello!");

    rt!.push({ kind: "SessionIdle", ocId: pc.promptCalls[0].id });
    await waitFor(200);

    uiWs.close();
  });

  it("injected message filtering: user prompt echo does not corrupt stream", async () => {
    const ribId = "rs-int-2";

    const { ws: uiWs, inbox } = makeUiClient(ribId);
    await waitFor(200);
    sendUiAttach(uiWs, ribId);
    await waitForNthMessage(inbox, "session_state", 1);

    sendUiEvent(uiWs, ribId, 1, "evt-1", "home-form", "submit");
    await waitFor(1000);

    expect(pc.promptCalls.length).toBeGreaterThanOrEqual(1);
    const ocId = pc.promptCalls[0].id;
    const injectedMsgId = pc.promptCalls[0].messageId!;

    const beforeInbox = inbox.length;
    rt!.push({
      kind: "PartUpdated",
      ocId,
      messageId: injectedMsgId,
      partType: "text",
      delta: Option.some("This is user prompt text that should be filtered out"),
    });
    rt!.push({ kind: "FlushBatch", ocId });
    await waitFor(RECONCILE_WAIT_MS);

    const newUpdates = inbox.slice(beforeInbox).filter((m) => m.kind === "template_update");
    const corrupted = newUpdates.filter((m) => {
      try {
        const tree = JSON.parse(m.tree as string);
        return JSON.stringify(tree).includes("This is user prompt text that should be filtered out");
      } catch { return false; }
    });
    expect(corrupted).toHaveLength(0);

    const modelJson = `{"kind":"container","id":"home-root","direction":"Vertical","children":[{"kind":"text","id":"home-title","text_type":"H2","value":"Second"},{"kind":"submittable","id":"home-form","value":[{"kind":"input","id":"home-input","value":""}],"button":{"kind":"button","id":"home-submit","label":"Submit","action":"Submit"}}]}`;

    for (let i = 0; i < modelJson.length; i++) {
      rt!.push({
        kind: "PartUpdated",
        ocId,
        messageId: "msg-model-2",
        partType: "text",
        delta: Option.some(modelJson[i]),
      });
    }
    rt!.push({ kind: "FlushBatch", ocId });
    await waitFor(RECONCILE_WAIT_MS);

    const secondUpdate = await waitForNthMessage(inbox.slice(beforeInbox), "template_update", 1);
    const secondTree = JSON.parse(secondUpdate.tree as string);
    expect(secondTree.children[0].value).toBe("Second");
    expect(secondTree.children[1].id).toBe("home-form");

    uiWs.close();
  });

  it("two-turn conversation: submit → stream → submit again → stream again", async () => {
    const ribId = "rs-int-3";

    const { ws: uiWs, inbox } = makeUiClient(ribId);
    await waitFor(200);
    sendUiAttach(uiWs, ribId);
    await waitForNthMessage(inbox, "session_state", 1);

    // Turn 1: submit
    sendUiEvent(uiWs, ribId, 1, "evt-1", "home-form", "submit");
    await waitFor(1000);
    expect(pc.promptCalls.length).toBe(1);
    const ocId = pc.promptCalls[0].id;

    const json1 = `{"kind":"container","id":"home-root","direction":"Vertical","children":[{"kind":"text","id":"home-title","text_type":"H2","value":"Turn 1"},{"kind":"submittable","id":"home-form","value":[{"kind":"input","id":"home-input","value":""}],"button":{"kind":"button","id":"home-submit","label":"Submit","action":"Submit"}}]}`;
    for (let i = 0; i < json1.length; i++) {
      rt!.push({ kind: "PartUpdated", ocId, messageId: "msg-3a", partType: "text", delta: Option.some(json1[i]) });
    }
    rt!.push({ kind: "FlushBatch", ocId });
    await waitFor(RECONCILE_WAIT_MS);
    rt!.push({ kind: "SessionIdle", ocId });
    await waitFor(200);

    const update1 = await waitForNthMessage(inbox, "template_update", 2);
    const tree1 = JSON.parse(update1.tree as string);
    expect(tree1.children[0].value).toBe("Turn 1");

    // Turn 2: submit again
    const revAfterTurn1 = update1.revision as number;
    sendUiEvent(uiWs, ribId, revAfterTurn1, "evt-2", "home-form", "submit");
    await waitFor(1000);
    expect(pc.promptCalls.length).toBe(2);

    const json2 = `{"kind":"container","id":"home-root","direction":"Vertical","children":[{"kind":"text","id":"home-title","text_type":"H2","value":"Turn 2"},{"kind":"submittable","id":"home-form","value":[{"kind":"input","id":"home-input","value":""}],"button":{"kind":"button","id":"home-submit","label":"Submit","action":"Submit"}}]}`;
    for (let i = 0; i < json2.length; i++) {
      rt!.push({ kind: "PartUpdated", ocId, messageId: "msg-3b", partType: "text", delta: Option.some(json2[i]) });
    }
    rt!.push({ kind: "FlushBatch", ocId });
    await waitFor(RECONCILE_WAIT_MS);

    const updates = inbox.filter((m) => m.kind === "template_update");
    const update2 = updates[updates.length - 1];
    const tree2 = JSON.parse(update2.tree as string);
    expect(tree2.children[0].value).toBe("Turn 2");

    uiWs.close();
  });
});
