export interface SessionState {
  sessionId: string;
  nonce: string;
  harnessConnected: boolean;
  pendingKickoff: boolean;
  treeRevision: number;
}

export type SessionMap = Map<string, SessionState>;

export function createSessionStore(): SessionMap {
  return new Map();
}

export function addSession(
  store: SessionMap,
  sessionId: string,
  nonce: string,
): SessionState {
  const state: SessionState = {
    sessionId,
    nonce,
    harnessConnected: false,
    pendingKickoff: true,
    treeRevision: 0,
  };
  store.set(sessionId, state);
  return state;
}

export function findSession(
  store: SessionMap,
  sessionId: string,
): SessionState | undefined {
  return store.get(sessionId);
}

export function removeSession(store: SessionMap, sessionId: string): boolean {
  return store.delete(sessionId);
}

export function markKickoffComplete(
  store: SessionMap,
  sessionId: string,
): SessionState | undefined {
  const s = store.get(sessionId);
  if (s) {
    s.pendingKickoff = false;
  }
  return s;
}

export function markHarnessConnected(
  store: SessionMap,
  sessionId: string,
): SessionState | undefined {
  const s = store.get(sessionId);
  if (s) {
    s.harnessConnected = true;
  }
  return s;
}

export function updateRevision(
  store: SessionMap,
  sessionId: string,
  revision: number,
): SessionState | undefined {
  const s = store.get(sessionId);
  if (s) {
    s.treeRevision = revision;
  }
  return s;
}

export function generateNonce(): string {
  return `oc-${Math.random().toString(36).slice(2, 10)}`;
}
