import {
  COMPONENT_KINDS,
  REJECTION_REASONS,
  type Cancel,
  type ComponentKind,
  type Disconnect,
  type EventRejection,
  type EventRejectionReason,
  type DecodeResult,
  type ServerMessage,
  type SessionState,
  type TemplateUpdate,
} from "../types/protocol";
import { err, ok } from "../types/protocol";

function isString(v: unknown): v is string {
  return typeof v === "string";
}

function isNumber(v: unknown): v is number {
  return typeof v === "number" && Number.isFinite(v);
}

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function field<T>(
  obj: Record<string, unknown>,
  name: string,
  decode: (v: unknown) => DecodeResult<T>,
): DecodeResult<T> {
  return name in obj ? decode(obj[name]) : err<T>(name, "missing field");
}

function optional<T>(
  obj: Record<string, unknown>,
  name: string,
  decode: (v: unknown) => DecodeResult<T>,
): DecodeResult<T | undefined> {
  return name in obj ? (obj[name] === undefined || obj[name] === null ? ok(undefined) : decode(obj[name])) : ok(undefined);
}

function decodeString(v: unknown): DecodeResult<string> {
  return isString(v) ? ok(v) : err("value", "expected string");
}

function decodeNumber(v: unknown): DecodeResult<number> {
  return isNumber(v) ? ok(v) : err("value", "expected number");
}

function decodeSessionState(v: unknown): DecodeResult<SessionState> {
  if (!isObject(v)) return err("session_state", "expected object");
  const session_id = field(v, "session_id", decodeString);
  if (!session_id.ok) return session_id;
  const mode = field(v, "mode", decodeString);
  if (!mode.ok) return mode;
  const revision = field(v, "revision", decodeNumber);
  if (!revision.ok) return revision;
  const tree = optional(v, "tree", decodeString);
  if (!tree.ok) return tree;
  const generation_id = optional(v, "generation_id", decodeString);
  if (!generation_id.ok) return generation_id;
  return ok({
    kind: "session_state",
    session_id: session_id.value,
    mode: mode.value,
    revision: revision.value,
    tree: tree.value,
    generation_id: generation_id.value,
  });
}

function decodeTemplateUpdate(v: unknown): DecodeResult<TemplateUpdate> {
  if (!isObject(v)) return err("template_update", "expected object");
  const session_id = field(v, "session_id", decodeString);
  if (!session_id.ok) return session_id;
  const revision = field(v, "revision", decodeNumber);
  if (!revision.ok) return revision;
  const tree = field(v, "tree", decodeString);
  if (!tree.ok) return tree;
  return ok({
    kind: "template_update",
    session_id: session_id.value,
    revision: revision.value,
    tree: tree.value,
  });
}

function decodeEventRejection(v: unknown): DecodeResult<EventRejection> {
  if (!isObject(v)) return err("event_rejection", "expected object");
  const session_id = field(v, "session_id", decodeString);
  if (!session_id.ok) return session_id;
  const event_id = field(v, "event_id", decodeString);
  if (!event_id.ok) return event_id;
  const reasonRaw = v["reason"];
  if (!isString(reasonRaw)) return err<EventRejection>("reason", "expected string");
  if (!(REJECTION_REASONS as readonly string[]).includes(reasonRaw)) return err<EventRejection>("reason", `expected one of ${REJECTION_REASONS.join(", ")}`);
  const reason: EventRejectionReason = reasonRaw as EventRejectionReason;
  return ok({
    kind: "event_rejection",
    session_id: session_id.value,
    event_id: event_id.value,
    reason: reason,
  });
}

export function decodeServerMessage(raw: string): DecodeResult<ServerMessage> {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return err("message", "invalid JSON");
  }

  if (!isObject(parsed)) return err("message", "expected object");
  const kind = field(parsed, "kind", decodeString);
  if (!kind.ok) return kind;

  switch (kind.value) {
    case "session_state": return decodeSessionState(parsed);
    case "template_update": return decodeTemplateUpdate(parsed);
    case "event_rejection": return decodeEventRejection(parsed);
    default:
      return err("kind", `unknown server message kind: ${kind.value}`);
  }
}

export function isComponentKind(v: string): v is ComponentKind {
  return (COMPONENT_KINDS as readonly string[]).includes(v);
}
