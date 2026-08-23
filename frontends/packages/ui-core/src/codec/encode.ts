import type {
  Attach,
  Cancel,
  ComponentEvent,
  ComponentKind,
  Disconnect,
} from "../types/protocol";

export function encodeAttach(sessionId: string, revision?: number): string {
  const msg: Attach = revision !== undefined
    ? { kind: "attach", session_id: sessionId, revision }
    : { kind: "attach", session_id: sessionId };
  return JSON.stringify(msg);
}

export function encodeComponentEvent(
  sessionId: string,
  revision: number,
  eventId: string,
  targetId: string,
  componentKind: ComponentKind,
  value?: string | number,
): string {
  const msg: ComponentEvent = value !== undefined
    ? { kind: "component_event", session_id: sessionId, revision, event_id: eventId, target_id: targetId, component_kind: componentKind, value }
    : { kind: "component_event", session_id: sessionId, revision, event_id: eventId, target_id: targetId, component_kind: componentKind };
  return JSON.stringify(msg);
}

export function encodeCancel(sessionId: string): string {
  const msg: Cancel = { kind: "cancel", session_id: sessionId };
  return JSON.stringify(msg);
}

export function encodeDisconnect(sessionId: string): string {
  const msg: Disconnect = { kind: "disconnect", session_id: sessionId };
  return JSON.stringify(msg);
}
