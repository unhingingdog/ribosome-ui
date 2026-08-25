import { Option } from "effect";

export type SessionPhase =
  | { readonly _tag: "Idle" }
  | { readonly _tag: "KickoffPending"; readonly callId: string }
  | {
      readonly _tag: "Streaming";
      readonly genId: string;
      readonly seq: number;
      readonly jsonStarted: boolean;
      readonly buffer: string;
      readonly pendingPrefix: string;
    }
  | { readonly _tag: "Completing"; readonly genId: string }
  | { readonly _tag: "AwaitingTurn" };

export interface SessionState {
  readonly ocId: string;
  readonly ribId: Option.Option<string>;
  readonly nonce: Option.Option<string>;
  readonly phase: SessionPhase;
  readonly queuedTurn: Option.Option<UserTurn>;
  readonly injectedMessageIds: ReadonlySet<string>;
}

export interface SessionStore {
  readonly sessions: ReadonlyMap<string, SessionState>;
  readonly pendingUiTurns: ReadonlyMap<string, UserTurn>;
}

export interface UserTurn {
  readonly sessionId: string;
  readonly tree: string;
  readonly event: string;
}

export type InputEvent =
  | { readonly kind: "ToolBefore"; readonly ocId: string; readonly tool: string; readonly callId: string; readonly nonce: string }
  | {
      readonly kind: "ToolAfter";
      readonly ocId: string;
      readonly tool: string;
      readonly callId: string;
      readonly output: string;
    }
  | {
      readonly kind: "PartUpdated";
      readonly ocId: string;
      readonly messageId: string;
      readonly partType: string;
      readonly delta: Option.Option<string>;
    }
  | { readonly kind: "SessionIdle"; readonly ocId: string }
  | { readonly kind: "SessionError"; readonly ocId: string; readonly error: Option.Option<string> }
  | { readonly kind: "UserTurnRecv"; readonly ribId: string; readonly tree: string; readonly event: string }
  | { readonly kind: "FlushBatch"; readonly ocId: string }
  | { readonly kind: "OcSessionCreated"; readonly ocId: string; readonly ribId: string }
  | { readonly kind: "WsOpen" }
  | { readonly kind: "WsClosed" };

export type Effect =
  | { readonly kind: "SendHarness"; readonly msg: HarnessOutbound }
  | { readonly kind: "CreateOcSession"; readonly ribId: string }
  | { readonly kind: "InjectPrompt"; readonly ocId: string; readonly text: string; readonly messageId: string };

export type HarnessOutbound =
  | { readonly kind: "attach"; readonly session_id: string; readonly harness_session_id: string; readonly nonce: string }
  | { readonly kind: "delta"; readonly session_id: string; readonly generation_id: string; readonly seq: number; readonly content: string }
  | { readonly kind: "generation_completed"; readonly session_id: string; readonly generation_id: string }
  | { readonly kind: "generation_failed"; readonly session_id: string; readonly generation_id: string; readonly reason: string | null };

export interface Transition {
  readonly store: SessionStore;
  readonly effects: ReadonlyArray<Effect>;
}

export interface AdapterConfig {
  readonly serverUrl: string;
  readonly mcpToolName: string;
}

export function createConfig(
  serverUrl: string,
  mcpToolName: string = "start",
): AdapterConfig {
  return { serverUrl, mcpToolName };
}

export function emptyStore(): SessionStore {
  return { sessions: new Map(), pendingUiTurns: new Map() };
}

export function generateNonce(): string {
  return `oc-${Math.random().toString(36).slice(2, 10)}`;
}

export function isStartTool(toolName: string, config: AdapterConfig): boolean {
  return toolName === config.mcpToolName || toolName.endsWith("_" + config.mcpToolName);
}

export function makeSession(ocId: string): SessionState {
  return {
    ocId,
    ribId: Option.none(),
    nonce: Option.none(),
    phase: { _tag: "Idle" },
    queuedTurn: Option.none(),
    injectedMessageIds: new Set(),
  };
}

export function setPhase(state: SessionState, phase: SessionPhase): SessionState {
  return { ...state, phase };
}

export function findSessionByRibId(store: SessionStore, ribId: string): SessionState | undefined {
  for (const s of store.sessions.values()) {
    if (Option.match(s.ribId, { onNone: () => false, onSome: (id) => id === ribId })) {
      return s;
    }
  }
  return undefined;
}

export function updateStore(
  store: SessionStore,
  ocId: string,
  fn: (s: SessionState) => SessionState,
): SessionStore {
  const s = store.sessions.get(ocId);
  if (!s) return store;
  const next = fn(s);
  const sessions = new Map(store.sessions);
  sessions.set(ocId, next);
  return { ...store, sessions };
}

export function putSession(store: SessionStore, state: SessionState): SessionStore {
  const sessions = new Map(store.sessions);
  sessions.set(state.ocId, state);
  return { ...store, sessions };
}

export function removeSession(store: SessionStore, ocId: string): SessionStore {
  const sessions = new Map(store.sessions);
  sessions.delete(ocId);
  return { ...store, sessions };
}

export const SessionPhase = {
  Idle: (): SessionPhase => ({ _tag: "Idle" }),
  KickoffPending: (callId: string): SessionPhase => ({ _tag: "KickoffPending", callId }),
  Streaming: (genId: string, seq: number, jsonStarted: boolean, buffer: string, pendingPrefix: string): SessionPhase => ({
    _tag: "Streaming",
    genId,
    seq,
    jsonStarted,
    buffer,
    pendingPrefix,
  }),
  Completing: (genId: string): SessionPhase => ({ _tag: "Completing", genId }),
  AwaitingTurn: (): SessionPhase => ({ _tag: "AwaitingTurn" }),
};
