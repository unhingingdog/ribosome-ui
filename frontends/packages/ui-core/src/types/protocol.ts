import type { Template } from "./template";

export type SessionId = string;

export type ServerMessage =
  | SessionState
  | TemplateUpdate
  | EventRejection;

export type ClientMessage =
  | Attach
  | ComponentEvent
  | Cancel
  | Disconnect;

export type Attach = {
  kind: "attach";
  session_id: SessionId;
  revision?: number;
};

export type ComponentKind = "click" | "change" | "submit";

export type ComponentEvent = {
  kind: "component_event";
  session_id: SessionId;
  revision: number;
  event_id: string;
  target_id: string;
  component_kind: ComponentKind;
  value?: string | number;
};

export type Cancel = {
  kind: "cancel";
  session_id: SessionId;
};

export type Disconnect = {
  kind: "disconnect";
  session_id: SessionId;
};

export type SessionState = {
  kind: "session_state";
  session_id: SessionId;
  mode: string;
  revision: number;
  tree?: string;
  generation_id?: string;
};

export type TemplateUpdate = {
  kind: "template_update";
  session_id: SessionId;
  revision: number;
  tree: string;
};

export type EventRejectionReason = "stale_revision" | "duplicate_event_id";

export type EventRejection = {
  kind: "event_rejection";
  session_id: SessionId;
  event_id: string;
  reason: EventRejectionReason;
};

export const COMPONENT_KINDS = ["click", "change", "submit"] as const;

export const REJECTION_REASONS = ["stale_revision", "duplicate_event_id"] as const;

export type DecodeError = {
  field: string;
  message: string;
};

export type DecodeResult<T> = { ok: true; value: T } | { ok: false; error: DecodeError };

export function ok<T>(value: T): DecodeResult<T> {
  return { ok: true, value };
}

export function err<T>(field: string, message: string): DecodeResult<T> {
  return { ok: false, error: { field, message } };
}

export type TemplateOrError = { ok: true; value: Template } | { ok: false; error: DecodeError };
