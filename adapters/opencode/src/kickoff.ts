import { generateNonce, type SessionState, type SessionMap } from "./session.js";

export interface PendingKickoff {
  callID: string;
  sessionID: string;
  nonce: string;
}

export interface HarnessAttachMessage {
  kind: "attach";
  session_id: string;
  harness_session_id: string;
  nonce: string;
}

export interface KickoffManager {
  recordPending(callID: string, sessionID: string): PendingKickoff;
  activate(
    callID: string,
    ribosomeSessionId: string,
    uiNonce: string,
  ): HarnessAttachMessage | null;
  clearPending(callID: string): PendingKickoff | null;
  getPending(callID: string): PendingKickoff | null;
  getActive(sessionID: string): SessionState | null;
  clearActive(sessionID: string): SessionState | null;
  readonly pendingCount: number;
  readonly activeCount: number;
}

export function createKickoffManager(sessions: SessionMap): KickoffManager {
  const pending = new Map<string, PendingKickoff>();

  return {
    recordPending(callID: string, sessionID: string): PendingKickoff {
      const nonce = generateNonce();
      const entry: PendingKickoff = { callID, sessionID, nonce };
      pending.set(callID, entry);
      return entry;
    },

    activate(
      callID: string,
      ribosomeSessionId: string,
      uiNonce: string,
    ): HarnessAttachMessage | null {
      const p = pending.get(callID);
      if (!p) return null;
      pending.delete(callID);

      sessions.set(p.sessionID, {
        sessionId: p.sessionID,
        nonce: p.nonce,
        harnessConnected: false,
        pendingKickoff: false,
        treeRevision: 0,
      });

      return {
        kind: "attach",
        session_id: ribosomeSessionId,
        harness_session_id: p.sessionID,
        nonce: p.nonce,
      };
    },

    clearPending(callID: string): PendingKickoff | null {
      const p = pending.get(callID);
      if (!p) return null;
      pending.delete(callID);
      return p;
    },

    getPending(callID: string): PendingKickoff | null {
      return pending.get(callID) ?? null;
    },

    getActive(sessionID: string): SessionState | null {
      return sessions.get(sessionID) ?? null;
    },

    clearActive(sessionID: string): SessionState | null {
      const s = sessions.get(sessionID);
      if (!s) return null;
      sessions.delete(sessionID);
      return s;
    },

    get pendingCount() {
      return pending.size;
    },

    get activeCount() {
      return sessions.size;
    },
  };
}
