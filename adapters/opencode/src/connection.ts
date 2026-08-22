export type ConnectionState =
  | "disconnected"
  | "connecting"
  | "connected"
  | "reconnecting"
  | "shutdown";

export interface WebSocketLike {
  readonly readyState: number;
  send(data: string): void;
  close(code?: number, reason?: string): void;
  onopen: ((ev: Event) => void) | null;
  onmessage: ((ev: MessageEvent) => void) | null;
  onclose: ((ev: CloseEvent) => void) | null;
  onerror: ((ev: Event) => void) | null;
}

export type WebSocketFactory = (url: string) => WebSocketLike;

export interface ConnectionManager {
  readonly state: ConnectionState;
  send(data: string): void;
  close(): void;
}

export function createConnectionManager(
  url: string,
  factory: WebSocketFactory,
  onMessage: (data: string) => void,
  onOpen?: () => void,
  onClose?: () => void,
): ConnectionManager {
  let ws: WebSocketLike | null = null;
  let state: ConnectionState = "disconnected";
  let shouldReconnect = true;
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  const reconnectDelay = 1000;
  const pendingQueue: string[] = [];

  function flushQueue() {
    while (pendingQueue.length > 0) {
      const msg = pendingQueue.shift()!;
      ws!.send(msg);
    }
  }

  function connect() {
    state = "connecting";
    ws = factory(url);

    ws.onopen = () => {
      state = "connected";
      flushQueue();
      if (onOpen) onOpen();
    };

    ws.onmessage = (ev: MessageEvent) => {
      onMessage(String(ev.data));
    };

    ws.onclose = () => {
      const wasShutdown = state === "shutdown";
      state = "disconnected";
      if (onClose) onClose();
      if (shouldReconnect && !wasShutdown) {
        state = "reconnecting";
        reconnectTimer = setTimeout(() => connect(), reconnectDelay);
      }
    };

    ws.onerror = () => {
      // Error handling: close will follow and trigger reconnect
    };
  }

  function send(data: string) {
    if (ws && state === "connected") {
      ws.send(data);
    } else if (state !== "shutdown") {
      pendingQueue.push(data);
    }
  }

  function close() {
    shouldReconnect = false;
    state = "shutdown";
    if (reconnectTimer) {
      clearTimeout(reconnectTimer);
      reconnectTimer = null;
    }
    if (ws) {
      ws.close(1000, "shutdown");
      ws = null;
    }
  }

  connect();

  return {
    get state() {
      return state;
    },
    send,
    close,
  };
}
