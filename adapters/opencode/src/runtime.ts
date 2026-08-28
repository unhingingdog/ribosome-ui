import { Subject, type Subscription } from "rxjs";
import { Either, Option } from "effect";
import type { AdapterConfig, Effect, HarnessOutbound, InputEvent, SessionStore } from "./types.js";
import { emptyStore } from "./types.js";
import { reduce } from "./reduce.js";
import { decodeHarnessInbound } from "./protocol.js";
import {
  createTransport,
  type Transport,
  type WebSocketFactory,
  FLUSH_INTERVAL_MS,
} from "./transport.js";
import { logInfo, logWarn, logError } from "./log.js";

export interface PromptClient {
  session: {
    create<ThrowOnError extends boolean = false>(options?: {
      body?: { parentID?: string; title?: string };
    }): Promise<{ data?: { id: string }; error?: unknown; response: Response }>;
    promptAsync<ThrowOnError extends boolean = false>(options: {
      path: { id: string };
      body?: {
        messageID?: string;
        parts: Array<{ type: "text"; text: string }>;
      };
    }): Promise<{ data?: unknown; error?: unknown; response: Response }>;
  };
}

export interface Runtime {
  push(event: InputEvent): void;
  shutdown(): void;
}

function whenSome<T>(opt: Option.Option<T>, f: (value: T) => void): void {
  Option.match(opt, { onNone: () => undefined, onSome: f });
}

export function createRuntime(
  config: AdapterConfig,
  wsFactory: WebSocketFactory,
  promptClient: PromptClient,
): Runtime {
  const events = new Subject<InputEvent>();
  let store: SessionStore = emptyStore();
  let flushTimer: Option.Option<ReturnType<typeof setInterval>> = Option.none();
  let wsSub: Option.Option<Subscription> = Option.none();
  let transport: Option.Option<Transport> = Option.none();

  function sendHarness(msg: HarnessOutbound): void {
    whenSome(transport, (t) => t.outbound.next(msg));
  }

  function createOcSession(ribId: string): void {
    logInfo("session", "creating oc session for UI-initiated turn", undefined);
    promptClient.session
      .create({ body: { title: "Ribosome" } })
      .then((result) => {
        if (result.data?.id) {
          logInfo("session", `created oc session ${result.data.id}`, result.data.id);
          events.next({ kind: "OcSessionCreated", ocId: result.data.id, ribId });
        } else {
          logError("session", "create returned no id", undefined);
        }
      })
      .catch((e) => {
        logError("session", `create failed: ${String(e)}`, undefined);
      });
  }

  function injectPrompt(ocId: string, text: string, messageId: string): void {
    logInfo("inject", "injecting prompt", ocId);
    promptClient.session
      .promptAsync({
        path: { id: ocId },
        body: { messageID: messageId, parts: [{ type: "text", text }] },
      })
      .then((res) => {
        if (res.response.status >= 400) {
          const detail = res.error === undefined ? "none" : JSON.stringify(res.error);
          logError("inject", `promptAsync failed status=${res.response.status} error=${detail}`, ocId);
        }
      })
      .catch((e) => {
        logError("inject", `failed: ${String(e)}`, ocId);
      });
  }

  function logEffect(eff: Effect): void {
    if (eff.kind !== "SendHarness") return;
    const msg = eff.msg;
    switch (msg.kind) {
      case "delta":
        logInfo("delta", `gen=${msg.generation_id} seq=${msg.seq} bytes=${msg.content.length}`, msg.session_id);
        break;
      case "generation_completed":
        logInfo("generation", `completed gen=${msg.generation_id}`, msg.session_id);
        break;
      case "generation_failed":
        logWarn("generation", `failed gen=${msg.generation_id} reason=${msg.reason ?? "none"}`, msg.session_id);
        break;
      case "attach":
        logInfo("harness", `attach ribosome=${msg.session_id} oc=${msg.harness_session_id}`, msg.harness_session_id);
        break;
    }
  }

  function executeEffect(eff: Effect): void {
    switch (eff.kind) {
      case "SendHarness":
        sendHarness(eff.msg);
        break;
      case "CreateOcSession":
        createOcSession(eff.ribId);
        break;
      case "InjectPrompt":
        injectPrompt(eff.ocId, eff.text, eff.messageId);
        break;
    }
  }

  function processEvent(event: InputEvent): void {
    const transition = reduce(store, event, config);
    store = transition.store;

    for (const eff of transition.effects) {
      logEffect(eff);
      executeEffect(eff);
    }
  }

  events.subscribe({
    next: processEvent,
    error: (e) => logError("runtime", `event stream error: ${String(e)}`, undefined),
    complete: () => {},
  });

  const tr = createTransport(
    `${config.serverUrl}/v1/harness`,
    wsFactory,
    () => {
      logInfo("harness", "websocket connected", undefined);
      events.next({ kind: "WsOpen" });
    },
    () => {
      logWarn("harness", "websocket disconnected, will reconnect", undefined);
      events.next({ kind: "WsClosed" });
    },
  );
  transport = Option.some(tr);

  const sub = tr.inbound.subscribe({
    next: (data) => {
      const decoded = decodeHarnessInbound(data);
      if (Either.isRight(decoded)) {
        logInfo("user-turn", `received for ${decoded.right.session_id}`, undefined);
        events.next({
          kind: "UserTurnRecv",
          ribId: decoded.right.session_id,
          tree: decoded.right.tree,
          event: decoded.right.event,
        });
      }
    },
  });
  wsSub = Option.some(sub);

  logInfo("adapter", "plugin loaded", undefined);

  const timer = setInterval(() => {
    for (const [ocId, state] of store.sessions) {
      if (state.phase._tag === "Streaming" && state.phase.buffer.length > 0) {
        events.next({ kind: "FlushBatch", ocId });
      }
    }
  }, FLUSH_INTERVAL_MS);
  flushTimer = Option.some(timer);

  return {
    push(event: InputEvent): void {
      events.next(event);
    },

    shutdown(): void {
      logInfo("adapter", "disposing", undefined);
      whenSome(flushTimer, clearInterval);
      flushTimer = Option.none();
      whenSome(wsSub, (s) => s.unsubscribe());
      wsSub = Option.none();
      whenSome(transport, (t) => t.close());
      transport = Option.none();
      events.complete();
    },
  };
}