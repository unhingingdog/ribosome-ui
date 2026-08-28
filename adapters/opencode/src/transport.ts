import { Subject, type Observable, type Subscription } from "rxjs";
import { Option } from "effect";
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

function whenSome<T>(opt: Option.Option<T>, f: (value: T) => void): void {
  Option.match(opt, { onNone: () => undefined, onSome: f });
}

export function createTransport(
  url: string,
  factory: WebSocketFactory,
  onOpen?: () => void,
  onClose?: () => void,
): Transport {
  const outbound = new Subject<HarnessOutbound>();
  const inbound = new Subject<string>();

  let ws: Option.Option<WebSocketLike> = Option.none();
  let shouldReconnect = true;
  let reconnectTimer: Option.Option<ReturnType<typeof setTimeout>> = Option.none();

  function connect() {
    const socket = factory(url);
    ws = Option.some(socket);

    socket.onopen = () => {
      if (onOpen) onOpen();
    };

    socket.onmessage = (ev: MessageEvent) => {
      inbound.next(String(ev.data));
    };

    socket.onclose = () => {
      if (onClose) onClose();
      if (shouldReconnect) {
        reconnectTimer = Option.some(setTimeout(() => connect(), RECONNECT_DELAY_MS));
      }
    };

    socket.onerror = () => {
      // close will follow and trigger reconnect
    };
  }

  function sendFrame(data: string) {
    whenSome(ws, (socket) => {
      if (socket.readyState !== 1) return;
      if (socket.bufferedAmount > FLUSH_BYTE_THRESHOLD) {
        setTimeout(() => sendFrame(data), FLUSH_INTERVAL_MS);
        return;
      }
      try {
        socket.send(data);
      } catch {
        // will reconnect via onclose
      }
    });
  }

  const sendSub: Subscription = outbound.subscribe({
    next: (msg) => sendFrame(encodeHarnessOutbound(msg)),
  });

  connect();

  return {
    outbound,
    inbound,
    close() {
      shouldReconnect = false;
      whenSome(reconnectTimer, clearTimeout);
      reconnectTimer = Option.none();
      sendSub.unsubscribe();
      outbound.complete();
      inbound.complete();
      whenSome(ws, (socket) => socket.close(1000, "shutdown"));
      ws = Option.none();
    },
  };
}