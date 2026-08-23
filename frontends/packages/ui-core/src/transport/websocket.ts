import { decodeServerMessage } from "../codec/decode";
import { encodeAttach, encodeCancel, encodeDisconnect } from "../codec/encode";
import type { ServerMessage } from "../types/protocol";
import { log } from "../debug";

export type TransportState = "disconnected" | "connecting" | "connected" | "reconnecting" | "shutdown";

export type TransportHandlers = {
  onMessage: (msg: ServerMessage) => void;
  onStateChange: (state: TransportState) => void;
  onError?: (error: Error) => void;
};

export type TransportOptions = {
  url: string;
  sessionId: string;
  revision?: number;
  handlers: TransportHandlers;
  reconnectDelay?: number;
  maxReconnectDelay?: number;
};

export class UiTransport {
  private ws: WebSocket | null = null;
  private state: TransportState = "disconnected";
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private reconnectAttempts = 0;
  private readonly opts: Required<Pick<TransportOptions, "reconnectDelay" | "maxReconnectDelay">> &
    Pick<TransportOptions, "url" | "sessionId" | "revision" | "handlers">;

  constructor(opts: TransportOptions) {
    this.opts = {
      reconnectDelay: 1000,
      maxReconnectDelay: 30000,
      ...opts,
    };
  }

  connect(): void {
    if (this.state === "shutdown") return;
    log("transport", `connecting to ${this.opts.url}`);
    this.setState("connecting");

    const ws = new WebSocket(this.opts.url);
    this.ws = ws;

    ws.onopen = () => {
      this.reconnectAttempts = 0;
      this.setState("connected");
      log("transport", "connected, sending attach");
      this.send(encodeAttach(this.opts.sessionId, this.opts.revision));
    };

    ws.onmessage = (event: MessageEvent) => {
      const raw = typeof event.data === "string" ? event.data : String(event.data);
      const result = decodeServerMessage(raw);
      if (result.ok) {
        log("transport", `recv ${result.value.kind} (${raw.length} bytes)`);
        this.opts.handlers.onMessage(result.value);
      } else {
        log("transport", `decode error: ${result.error.field}: ${result.error.message}`);
        this.opts.handlers.onError?.(new Error(`Decode error: ${result.error.field}: ${result.error.message}`));
      }
    };

    ws.onerror = () => {
      log("transport", "websocket error");
      this.opts.handlers.onError?.(new Error("WebSocket error"));
    };

    ws.onclose = () => {
      if (this.state === "shutdown") return;
      log("transport", "closed, scheduling reconnect");
      this.scheduleReconnect();
    };
  }

  send(raw: string): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(raw);
    }
  }

  cancel(): void {
    log("transport", "sending cancel");
    this.send(encodeCancel(this.opts.sessionId));
  }

  disconnect(): void {
    log("transport", "disconnecting");
    this.setState("shutdown");
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    if (this.ws) {
      if (this.ws.readyState === WebSocket.OPEN) {
        this.send(encodeDisconnect(this.opts.sessionId));
      }
      this.ws.onclose = null;
      this.ws.close();
      this.ws = null;
    }
    this.setState("disconnected");
  }

  getState(): TransportState {
    return this.state;
  }

  setHandlers(handlers: TransportHandlers): void {
    this.opts.handlers = handlers;
  }

  private scheduleReconnect(): void {
    this.setState("reconnecting");
    const delay = Math.min(
      this.opts.reconnectDelay * Math.pow(2, this.reconnectAttempts),
      this.opts.maxReconnectDelay,
    );
    this.reconnectAttempts++;
    log("transport", `reconnect in ${delay}ms (attempt ${this.reconnectAttempts})`);
    this.reconnectTimer = setTimeout(() => this.connect(), delay);
  }

  private setState(state: TransportState): void {
    this.state = state;
    this.opts.handlers.onStateChange(state);
  }
}
