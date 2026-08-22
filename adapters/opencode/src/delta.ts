export interface HarnessDeltaMessage {
  kind: "delta";
  session_id: string;
  generation_id: string;
  seq: number;
  content: string;
}

export interface HarnessGenerationCompletedMessage {
  kind: "generation_completed";
  session_id: string;
  generation_id: string;
}

export interface HarnessGenerationFailedMessage {
  kind: "generation_failed";
  session_id: string;
  generation_id: string;
  reason: string | null;
}

export type HarnessOutboundMessage =
  | HarnessDeltaMessage
  | HarnessGenerationCompletedMessage
  | HarnessGenerationFailedMessage;

export interface GenerationState {
  generationId: string;
  seq: number;
}

export type GenerationMap = Map<string, GenerationState>;

export interface DeltaForwarder {
  handlePartDelta(
    sessionID: string,
    messageID: string,
    partType: string,
    delta: string | undefined,
  ): HarnessDeltaMessage | null;

  handleSessionIdle(sessionID: string): HarnessGenerationCompletedMessage | null;

  handleSessionError(
    sessionID: string,
    errorMessage?: string,
  ): HarnessGenerationFailedMessage | null;

  hasActiveGeneration(sessionID: string): boolean;
  clearGeneration(sessionID: string): void;
  readonly activeGenerationCount: number;
}

export function createDeltaForwarder(
  activeSessions: Set<string>,
  harnessSessionIdMap: Map<string, string>,
): DeltaForwarder {
  const generations: GenerationMap = new Map();

  return {
    handlePartDelta(
      sessionID: string,
      messageID: string,
      partType: string,
      delta: string | undefined,
    ): HarnessDeltaMessage | null {
      if (!activeSessions.has(sessionID)) return null;
      if (partType !== "text") return null;
      if (!delta) return null;

      const ribosomeSessionId = harnessSessionIdMap.get(sessionID);
      if (!ribosomeSessionId) return null;

      let gen = generations.get(sessionID);
      if (!gen) {
        gen = { generationId: messageID, seq: 0 };
        generations.set(sessionID, gen);
      }

      const msg: HarnessDeltaMessage = {
        kind: "delta",
        session_id: ribosomeSessionId,
        generation_id: gen.generationId,
        seq: gen.seq,
        content: delta,
      };

      gen.seq += 1;
      return msg;
    },

    handleSessionIdle(
      sessionID: string,
    ): HarnessGenerationCompletedMessage | null {
      const gen = generations.get(sessionID);
      if (!gen) return null;

      const ribosomeSessionId = harnessSessionIdMap.get(sessionID);
      if (!ribosomeSessionId) return null;

      const msg: HarnessGenerationCompletedMessage = {
        kind: "generation_completed",
        session_id: ribosomeSessionId,
        generation_id: gen.generationId,
      };

      generations.delete(sessionID);
      return msg;
    },

    handleSessionError(
      sessionID: string,
      errorMessage?: string,
    ): HarnessGenerationFailedMessage | null {
      const gen = generations.get(sessionID);
      if (!gen) return null;

      const ribosomeSessionId = harnessSessionIdMap.get(sessionID);
      if (!ribosomeSessionId) return null;

      const msg: HarnessGenerationFailedMessage = {
        kind: "generation_failed",
        session_id: ribosomeSessionId,
        generation_id: gen.generationId,
        reason: errorMessage ?? null,
      };

      generations.delete(sessionID);
      return msg;
    },

    hasActiveGeneration(sessionID: string): boolean {
      return generations.has(sessionID);
    },

    clearGeneration(sessionID: string): void {
      generations.delete(sessionID);
    },

    get activeGenerationCount() {
      return generations.size;
    },
  };
}
