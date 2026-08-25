import { describe, it, expect, vi } from "vitest";
import { createTransport, type WebSocketLike } from "../src/transport.js";

class FakeWebSocket implements WebSocketLike {
  readyState = 0;
  bufferedAmount = 0;
  onopen: ((ev: Event) => void) | null = null;
  onmessage: ((ev: MessageEvent) => void) | null = null;
  onclose: ((ev: CloseEvent) => void) | null = null;
  onerror: ((ev: Event) => void) | null = null;
  sent: string[] = [];
  closed = false;

  send(data: string): void {
    this.sent.push(data);
  }

  close(_code?: number, _reason?: string): void {
    this.closed = true;
    this.readyState = 3;
  }

  fireOpen() {
    this.readyState = 1;
    if (this.onopen) this.onopen(new Event("open"));
  }

  fireMessage(data: string) {
    if (this.onmessage) this.onmessage({ data } as MessageEvent);
  }

  fireClose() {
    if (this.onclose) this.onclose(new CloseEvent("close"));
  }
}

describe("transport", () => {
  it("sends messages when connected", () => {
    const fake = new FakeWebSocket();
    const transport = createTransport("ws://test", () => fake);
    fake.fireOpen();

    transport.outbound.next({
      kind: "attach",
      session_id: "rs-1",
      harness_session_id: "oc-1",
      nonce: "abc",
    });

    expect(fake.sent).toHaveLength(1);
    const parsed = JSON.parse(fake.sent[0]);
    expect(parsed.kind).toBe("attach");

    transport.close();
  });

  it("delivers inbound messages", () => {
    const fake = new FakeWebSocket();
    const received: string[] = [];
    const transport = createTransport("ws://test", () => fake);
    transport.inbound.subscribe((data) => received.push(data));

    fake.fireOpen();
    fake.fireMessage('{"kind":"user_turn","session_id":"rs-1","tree":"{}","event":"{}"}');

    expect(received).toHaveLength(1);
    expect(JSON.parse(received[0]).kind).toBe("user_turn");

    transport.close();
  });

  it("fires onOpen callback", () => {
    const fake = new FakeWebSocket();
    const onOpen = vi.fn();
    const transport = createTransport("ws://test", () => fake, onOpen);
    fake.fireOpen();
    expect(onOpen).toHaveBeenCalledOnce();
    transport.close();
  });

  it("fires onClose callback", () => {
    const fake = new FakeWebSocket();
    const onClose = vi.fn();
    const transport = createTransport("ws://test", () => fake, undefined, onClose);
    fake.fireOpen();
    fake.fireClose();
    expect(onClose).toHaveBeenCalledOnce();
    transport.close();
  });

  it("does not reconnect after shutdown close", () => {
    const fake = new FakeWebSocket();
    const onClose = vi.fn();
    const transport = createTransport("ws://test", () => fake, undefined, onClose);
    fake.fireOpen();
    transport.close();
    fake.fireClose();
    expect(onClose).toHaveBeenCalledOnce();
  });
});
