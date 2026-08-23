import { encodeComponentEvent } from "../codec/encode";
import { log } from "../debug";
import type { ComponentKind } from "../types/protocol";
import type { SessionStoreApi } from "./session-store";
import type { UiTransport } from "../transport/websocket";

export type EventDispatch = {
  sendComponentEvent: (targetId: string, kind: ComponentKind, value?: string | number) => void;
  sendCancel: () => void;
  sendDisconnect: () => void;
};

export function createEventDispatch(store: SessionStoreApi, transport: UiTransport): EventDispatch {
  let eventCounter = 0;

  const nextEventId = (): string => {
    eventCounter++;
    return `evt-${Date.now()}-${eventCounter}`;
  };

  const sendComponentEvent = (
    targetId: string,
    kind: ComponentKind,
    value?: string | number,
  ): void => {
    const sessionId = store.store.sessionId;
    const revision = store.store.revision;
    const eventId = nextEventId();
    log("dispatch", `send ${kind} target=${targetId} event_id=${eventId} rev=${revision}`);
    transport.send(encodeComponentEvent(sessionId, revision, eventId, targetId, kind, value));
  };

  return {
    sendComponentEvent,
    sendCancel: () => {
      log("dispatch", "send cancel");
      transport.cancel();
    },
    sendDisconnect: () => {
      log("dispatch", "send disconnect");
      transport.disconnect();
    },
  };
}
