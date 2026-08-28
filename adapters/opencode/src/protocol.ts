import { Either, Option } from "effect";
import type { HarnessOutbound } from "./types.js";

export interface UserTurnMessage {
  readonly kind: "user_turn";
  readonly session_id: string;
  readonly tree: string;
  readonly event: string;
}

export type HarnessInbound = UserTurnMessage;

export type DecodeError =
  | { readonly tag: "invalid_json" }
  | { readonly tag: "not_an_object" }
  | { readonly tag: "unexpected_kind"; readonly kind: string }
  | { readonly tag: "missing_field"; readonly field: string };

export function encodeHarnessOutbound(msg: HarnessOutbound): string {
  return JSON.stringify(msg);
}

function parseJson(data: string): Option.Option<unknown> {
  try {
    return Option.some(JSON.parse(data));
  } catch {
    return Option.none();
  }
}

function readString(rec: Record<string, unknown>, field: string): Either.Either<string, DecodeError> {
  const value = rec[field];
  return typeof value === "string"
    ? Either.right(value)
    : Either.left({ tag: "missing_field", field });
}

function decodeUserTurn(value: unknown): Either.Either<HarnessInbound, DecodeError> {
  if (typeof value !== "object" || value === null) {
    return Either.left({ tag: "not_an_object" });
  }

  const rec = value as Record<string, unknown>;
  if (rec.kind !== "user_turn") {
    return Either.left({ tag: "unexpected_kind", kind: String(rec.kind) });
  }

  const sessionId = readString(rec, "session_id");
  if (Either.isLeft(sessionId)) return Either.left(sessionId.left);

  const tree = readString(rec, "tree");
  if (Either.isLeft(tree)) return Either.left(tree.left);

  const event = readString(rec, "event");
  if (Either.isLeft(event)) return Either.left(event.left);

  return Either.right({
    kind: "user_turn",
    session_id: sessionId.right,
    tree: tree.right,
    event: event.right,
  });
}

export function decodeHarnessInbound(data: string): Either.Either<HarnessInbound, DecodeError> {
  return Option.match(parseJson(data), {
    onNone: () => Either.left({ tag: "invalid_json" }),
    onSome: decodeUserTurn,
  });
}