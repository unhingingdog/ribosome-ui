import { Subject, Subscription } from "rxjs";
import { Either, Option } from "effect";
import type { AdapterConfig, Effect, InputEvent, SessionStore } from "./types.js";
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

export function createRuntime(
  config: AdapterConfig,
  wsFactory: WebSocketFactory,
  promptClient: PromptClient,
): Runtime {
  const events = new Subject<InputEvent>();
  let store: SessionStore = emptyStore();
  let flushTimer: ReturnType<typeof setInterval> | null = null;
  let wsSub: Subscription | null = null;
  let transport: Transport | null = null;

  function executeEffect(eff: Effect): void {
    switch (eff.kind) {
      case "SendHarness":
        if (transport) {
          transport.outbound.next(eff.msg);
        }
        break;

      case "CreateOcSession":
        logInfo("session", "creating oc session for UI-initiated turn", undefined);
        promptClient.session
          .create({ body: { title: "Ribosome" } })
          .then((result) => {
            if (result.data?.id) {
              logInfo("session", `created oc session ${result.data.id}`, result.data.id);
              events.next({
                kind: "OcSessionCreated",
                ocId: result.data.id,
                ribId: eff.ribId,
              });
            } else {
              logError("session", "create returned no id", undefined);
            }
          })
          .catch((e) => {
            logError("session", `create failed: ${String(e)}`, undefined);
          });
        break;

      case "InjectPrompt": {
        logInfo("inject", "injecting prompt", eff.ocId);
        promptClient.session
          .promptAsync({
            path: { id: eff.ocId },
            body: {
              messageID: eff.messageId,
              parts: [{ type: "text", text: eff.text }],
            },
          })
          .then((res) => {
            if (res.response.status >= 400) {
              logError("inject", `promptAsync failed status=${res.response.status} error=${JSON.stringify(res.error ?? null)}`, eff.ocId);
            }
          })
          .catch((e) => {
            logError("inject", `failed: ${String(e)}`, eff.ocId);
          });
        break;
      }
    }
  }

  function processEvent(event: InputEvent): void {
    const transition = reduce(store, event, config);
    store = transition.store;

    for (const eff of transition.effects) {
      if (eff.kind === "SendHarness") {
        const msg = eff.msg;
        if (msg.kind === "delta") {
          logInfo("delta", `gen=${msg.generation_id} seq=${msg.seq} bytes=${msg.content.length}`, msg.session_id);
        } else if (msg.kind === "generation_completed") {
          logInfo("generation", `completed gen=${msg.generation_id}`, msg.session_id);
        } else if (msg.kind === "generation_failed") {
          logWarn("generation", `failed gen=${msg.generation_id} reason=${msg.reason ?? "none"}`, msg.session_id);
        } else if (msg.kind === "attach") {
          logInfo("harness", `attach ribosome=${msg.session_id} oc=${msg.harness_session_id}`, msg.harness_session_id);
        }
      }
      executeEffect(eff);
    }
  }

  events.subscribe({
    next: processEvent,
    error: (e) => logError("runtime", `event stream error: ${String(e)}`, undefined),
    complete: () => {},
  });

  transport = createTransport(
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

  wsSub = transport.inbound.subscribe({
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

  logInfo("adapter", "plugin loaded", undefined);

  flushTimer = setInterval(() => {
    for (const [ocId, state] of store.sessions) {
      if (state.phase._tag === "Streaming" && state.phase.buffer.length > 0) {
        events.next({ kind: "FlushBatch", ocId });
      }
    }
  }, FLUSH_INTERVAL_MS);

  return {
    push(event: InputEvent): void {
      events.next(event);
    },

    shutdown(): void {
      logInfo("adapter", "disposing", undefined);
      if (flushTimer) {
        clearInterval(flushTimer);
        flushTimer = null;
      }
      if (wsSub) {
        wsSub.unsubscribe();
        wsSub = null;
      }
      if (transport) {
        transport.close();
        transport = null;
      }
      events.complete();
    },
  };
}
