import type { Hooks, PluginInput, PluginOptions } from "@opencode-ai/plugin";
import { type AdapterConfig, createConfig } from "./config.js";
import {
  createSessionStore,
  type SessionMap,
} from "./session.js";
import {
  createKickoffManager,
  type KickoffManager,
  type HarnessAttachMessage,
} from "./kickoff.js";
import {
  createConnectionManager,
  type ConnectionManager,
  type WebSocketFactory,
} from "./connection.js";
import {
  createDeltaForwarder,
  type DeltaForwarder,
} from "./delta.js";

export interface AdapterContext {
  config: AdapterConfig;
  sessions: SessionMap;
  kickoff: KickoffManager;
  delta: DeltaForwarder;
  harnessConn: ConnectionManager | null;
  wsFactory: WebSocketFactory;
  activeSessionIds: Set<string>;
  harnessSessionIdMap: Map<string, string>;
}

export function createAdapterContext(
  config: AdapterConfig,
  wsFactory: WebSocketFactory,
): AdapterContext {
  const sessions = createSessionStore();
  const kickoff = createKickoffManager(sessions);
  const activeSessionIds = new Set<string>();
  const harnessSessionIdMap = new Map<string, string>();
  const delta = createDeltaForwarder(activeSessionIds, harnessSessionIdMap);
  return {
    config,
    sessions,
    kickoff,
    delta,
    harnessConn: null,
    wsFactory,
    activeSessionIds,
    harnessSessionIdMap,
  };
}

function isStartTool(toolName: string, config: AdapterConfig): boolean {
  return toolName === config.mcpToolName;
}

function parseStartResult(
  output: string,
): { session_id: string; ui_nonce: string } | null {
  try {
    const parsed = JSON.parse(output);
    if (
      parsed &&
      typeof parsed.session_id === "string" &&
      typeof parsed.ui_nonce === "string"
    ) {
      return { session_id: parsed.session_id, ui_nonce: parsed.ui_nonce };
    }
  } catch {
    // output may not be JSON
  }
  return null;
}

export function createHooks(ctx: AdapterContext): Hooks {
  return {
    "tool.execute.before": async (input, output) => {
      if (!isStartTool(input.tool, ctx.config)) return;
      const pending = ctx.kickoff.recordPending(input.callID, input.sessionID);
      if (output.args && typeof output.args === "object") {
        (output.args as Record<string, unknown>)._harness_session_id =
          pending.sessionID;
        (output.args as Record<string, unknown>)._nonce = pending.nonce;
      }
    },

    "tool.execute.after": async (input, output) => {
      if (!isStartTool(input.tool, ctx.config)) return;
      const result = parseStartResult(output.output);
      if (!result) {
        ctx.kickoff.clearPending(input.callID);
        return;
      }
      const attachMsg = ctx.kickoff.activate(
        input.callID,
        result.session_id,
        result.ui_nonce,
      );
      if (!attachMsg) return;

      if (!ctx.harnessConn) {
        const harnessUrl = ctx.config.serverUrl + "/v1/harness";
        ctx.harnessConn = createConnectionManager(
          harnessUrl,
          ctx.wsFactory,
          () => {},
        );
      }

      ctx.harnessConn.send(JSON.stringify(attachMsg));

      ctx.activeSessionIds.add(input.sessionID);
      ctx.harnessSessionIdMap.set(input.sessionID, result.session_id);
    },

    event: async (input) => {
      const ev = input.event;

      if (ev.type === "message.part.updated") {
        const part = ev.properties.part;
        const deltaStr = ev.properties.delta;
        const msg = ctx.delta.handlePartDelta(
          part.sessionID,
          part.messageID,
          part.type,
          deltaStr,
        );
        if (msg && ctx.harnessConn) {
          ctx.harnessConn.send(JSON.stringify(msg));
        }
        return;
      }

      if (ev.type === "session.idle") {
        const sessionID = ev.properties.sessionID;
        const session = ctx.sessions.get(sessionID);
        if (session) {
          session.pendingKickoff = false;
        }
        const completed = ctx.delta.handleSessionIdle(sessionID);
        if (completed && ctx.harnessConn) {
          ctx.harnessConn.send(JSON.stringify(completed));
        }
        return;
      }

      if (ev.type === "session.error") {
        const sessionID = ev.properties.sessionID;
        if (sessionID) {
          const failed = ctx.delta.handleSessionError(
            sessionID,
            ev.properties.error
              ? JSON.stringify(ev.properties.error)
              : undefined,
          );
          if (failed && ctx.harnessConn) {
            ctx.harnessConn.send(JSON.stringify(failed));
          }
          ctx.kickoff.clearActive(sessionID);
          ctx.activeSessionIds.delete(sessionID);
          ctx.harnessSessionIdMap.delete(sessionID);
        }
        return;
      }
    },

    dispose: async () => {
      if (ctx.harnessConn) {
        ctx.harnessConn.close();
        ctx.harnessConn = null;
      }
    },
  };
}

export function createPlugin(
  wsFactory: WebSocketFactory,
  defaultConfig?: Partial<AdapterConfig>,
): (input: PluginInput, options?: PluginOptions) => Promise<Hooks> {
  return async (_input, options) => {
    const config = createConfig(
      defaultConfig?.serverUrl ?? "ws://127.0.0.1:8787",
      defaultConfig?.mcpToolName,
    );
    const ctx = createAdapterContext(config, wsFactory);
    return createHooks(ctx);
  };
}
