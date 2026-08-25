import { Subject, Observable, Subscription } from "rxjs";
import type { HarnessOutbound } from "./types.js";
import { encodeHarnessOutbound } from "./protocol.js";

export const FLUSH_INTERVAL_MS = 50;
export const FLUSH_BYTE_THRESHOLD = 4096;
const RECONNECT_DELAY_MS = 1000;

export interface WebSocketLike {
  readonly readyState: number;
  readonly bufferedAmount: number;
  send(data: string): void;
  close(code?: number, reason?: string): void;
  onopen: ((ev: Event) => void) | null;
  onmessage: ((ev: MessageEvent) => void) | null;
  onclose: ((ev: CloseEvent) => void) | null;
  onerror: ((ev: Event) => void) | null;
}

export type WebSocketFactory = (url: string) => WebSocketLike;

export interface Transport {
  readonly outbound: Subject<HarnessOutbound>;
  readonly inbound: Observable<string>;
  close(): void;
}

export function createTransport(
  url: string,
  factory: WebSocketFactory,
  onOpen?: () => void,
  onClose?: () => void,
): Transport {
  const outbound = new Subject<HarnessOutbound>();
  const inbound = new Subject<string>();

  let ws: WebSocketLike | null = null;
  let shouldReconnect = true;
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  let sendSub: Subscription;

  function connect() {
    ws = factory(url);

    ws.onopen = () => {
      if (onOpen) onOpen();
    };

    ws.onmessage = (ev: MessageEvent) => {
      inbound.next(String(ev.data));
    };

    ws.onclose = () => {
      if (onClose) onClose();
      if (shouldReconnect) {
        reconnectTimer = setTimeout(() => connect(), RECONNECT_DELAY_MS);
      }
    };

    ws.onerror = () => {
      // close will follow and trigger reconnect
    };
  }

  function sendFrame(data: string) {
    if (!ws || ws.readyState !== 1) return;
    if (ws.bufferedAmount > FLUSH_BYTE_THRESHOLD) {
      setTimeout(() => sendFrame(data), FLUSH_INTERVAL_MS);
      return;
    }
    try {
      ws.send(data);
    } catch {
      // will reconnect via onclose
    }
  }

  sendSub = outbound
    .pipe(
      // Coalesce rapid deltas into single frames
      // Each message is still a separate JSON object, but they share TCP frames
    )
    .subscribe({
      next: (msg) => sendFrame(encodeHarnessOutbound(msg)),
    });

  connect();

  return {
    outbound,
    inbound,
    close() {
      shouldReconnect = false;
      if (reconnectTimer) {
        clearTimeout(reconnectTimer);
        reconnectTimer = null;
      }
      sendSub.unsubscribe();
      outbound.complete();
      inbound.complete();
      if (ws) {
        ws.close(1000, "shutdown");
        ws = null;
      }
    },
  };
}
