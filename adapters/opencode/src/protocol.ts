import { Either } from "effect";
import type { HarnessOutbound } from "./types.js";

export interface UserTurnMessage {
  readonly kind: "user_turn";
  readonly session_id: string;
  readonly tree: string;
  readonly event: string;
}

export type HarnessInbound = UserTurnMessage;

export function encodeHarnessOutbound(msg: HarnessOutbound): string {
  return JSON.stringify(msg);
}

export function decodeHarnessInbound(data: string): Either.Either<HarnessInbound, string> {
  let parsed: unknown;
  try {
    parsed = JSON.parse(data);
  } catch {
    return Either.left("invalid json");
  }

  if (typeof parsed !== "object" || parsed === null) {
    return Either.left("not an object");
  }

  const obj = parsed as Record<string, unknown>;
  if (obj.kind !== "user_turn") {
    return Either.left(`unexpected kind: ${String(obj.kind)}`);
  }
  if (typeof obj.session_id !== "string") {
    return Either.left("missing session_id");
  }
  if (typeof obj.tree !== "string") {
    return Either.left("missing tree");
  }
  if (typeof obj.event !== "string") {
    return Either.left("missing event");
  }

  return Either.right({
    kind: "user_turn",
    session_id: obj.session_id,
    tree: obj.tree,
    event: obj.event,
  });
}
