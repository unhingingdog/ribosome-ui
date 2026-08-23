export interface UserTurnMessage {
  kind: "user_turn";
  session_id: string;
  tree: string;
  event: string;
}

export interface SubmissionPayload {
  sessionID: string;
  text: string;
}

export interface PromptClient {
  sessionCreate(options?: { body?: { title?: string } }): Promise<{
    data?: { id: string };
  }>;
  promptAsync(body: {
    path: { id: string };
    body: {
      parts: Array<{ type: "text"; text: string }>;
    };
  }): Promise<unknown>;
}

export interface SubmissionInjector {
  handleUserTurn(msg: UserTurnMessage): SubmissionPayload | null;
  flushQueue(sessionID: string): SubmissionPayload | null;
  isQueued(sessionID: string): boolean;
  hasActive(sessionID: string): boolean;
  clear(sessionID: string): void;
  readonly queuedCount: number;
}

export function formatSubmission(tree: string, event: string): string {
  const eventJson = JSON.parse(event);
  const parts: string[] = [];

  parts.push("[ribosome-tree]");
  parts.push(tree);
  parts.push("[/ribosome-tree]");

  parts.push("[ribosome-event]");
  parts.push(JSON.stringify(eventJson, null, 2));
  parts.push("[/ribosome-event]");

  return parts.join("\n");
}

export function createSubmissionInjector(
  activeSessions: Set<string>,
  harnessSessionIdMap: Map<string, string>,
): SubmissionInjector {
  const active = new Set<string>();
  const queued = new Map<string, SubmissionPayload>();

  function findOcSession(ribosomeSessionId: string): string | null {
    for (const [ocId, ribId] of harnessSessionIdMap) {
      if (ribId === ribosomeSessionId) return ocId;
    }
    return null;
  }

  return {
    handleUserTurn(msg: UserTurnMessage): SubmissionPayload | null {
      if (!activeSessions.size) return null;

      const ocSessionId = findOcSession(msg.session_id);
      if (!ocSessionId) return null;

      const text = formatSubmission(msg.tree, msg.event);
      const payload: SubmissionPayload = { sessionID: ocSessionId, text };

      if (active.has(ocSessionId)) {
        if (!queued.has(ocSessionId)) {
          queued.set(ocSessionId, payload);
        }
        return null;
      }

      active.add(ocSessionId);
      return payload;
    },

    flushQueue(sessionID: string): SubmissionPayload | null {
      active.delete(sessionID);

      const next = queued.get(sessionID);
      if (next) {
        queued.delete(sessionID);
        active.add(sessionID);
        return next;
      }

      return null;
    },

    isQueued(sessionID: string): boolean {
      return queued.has(sessionID);
    },

    hasActive(sessionID: string): boolean {
      return active.has(sessionID);
    },

    clear(sessionID: string): void {
      active.delete(sessionID);
      queued.delete(sessionID);
    },

    get queuedCount() {
      return queued.size;
    },
  };
}
