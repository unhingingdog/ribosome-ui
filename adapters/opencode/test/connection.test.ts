import { describe, it, expect, vi } from "vitest";
import { createConnectionManager, type WebSocketLike } from "../src/connection.js";

class FakeWebSocket implements WebSocketLike {
  readyState = 0;
  onopen: ((ev: Event) => void) | null = null;
  onmessage: ((ev: MessageEvent) => void) | null = null;
  onclose: ((ev: CloseEvent) => void) | null = null;
  onerror: ((ev: Event) => void) | null = null;
  sent: string[] = [];
  closed = false;
  closeCode: number | undefined;
  closeReason: string | undefined;

  send(data: string): void {
    this.sent.push(data);
  }

  close(code?: number, reason?: string): void {
    this.closed = true;
    this.closeCode = code;
    this.closeReason = reason;
    this.readyState = 3;
  }

  fireOpen() {
    this.readyState = 1;
    if (this.onopen) this.onopen(new Event("open"));
  }

  fireMessage(data: string) {
    if (this.onmessage)
      this.onmessage({ data } as MessageEvent);
  }

  fireClose() {
    if (this.onclose) this.onclose({} as CloseEvent);
  }
}

describe("connection", () => {
  it("connects and receives messages", () => {
    const fake = new FakeWebSocket();
    const messages: string[] = [];
    const mgr = createConnectionManager(
      "ws://test",
      () => fake,
      (d) => messages.push(d),
    );

    fake.fireOpen();
    expect(mgr.state).toBe("connected");

    fake.fireMessage("hello");
    expect(messages).toEqual(["hello"]);
  });

  it("queues messages until connected, then flushes", () => {
    const fake = new FakeWebSocket();
    const mgr = createConnectionManager("ws://test", () => fake, () => {});

    mgr.send("queued-1");
    mgr.send("queued-2");
    expect(fake.sent).toEqual([]);

    fake.fireOpen();
    expect(fake.sent).toEqual(["queued-1", "queued-2"]);
  });

  it("sends when connected", () => {
    const fake = new FakeWebSocket();
    const mgr = createConnectionManager(
      "ws://test",
      () => fake,
      () => {},
    );

    fake.fireOpen();
    mgr.send("test-data");
    expect(fake.sent).toEqual(["test-data"]);
  });

  it("does not send when disconnected", () => {
    const fake = new FakeWebSocket();
    const mgr = createConnectionManager(
      "ws://test",
      () => fake,
      () => {},
    );

    mgr.send("nope");
    expect(fake.sent).toEqual([]);
  });

  it("calls onOpen callback", () => {
    const fake = new FakeWebSocket();
    const onOpen = vi.fn();
    createConnectionManager("ws://test", () => fake, () => {}, onOpen);

    fake.fireOpen();
    expect(onOpen).toHaveBeenCalledOnce();
  });

  it("calls onClose callback", () => {
    const fake = new FakeWebSocket();
    const onClose = vi.fn();
    createConnectionManager("ws://test", () => fake, () => {}, undefined, onClose);

    fake.fireClose();
    expect(onClose).toHaveBeenCalledOnce();
  });

  it("shuts down and prevents reconnect", () => {
    const fake = new FakeWebSocket();
    const mgr = createConnectionManager("ws://test", () => fake, () => {});

    fake.fireOpen();
    mgr.close();

    expect(fake.closed).toBe(true);
    expect(fake.closeCode).toBe(1000);
    expect(mgr.state).toBe("shutdown");
  });

  it("schedules reconnect on close", () => {
    vi.useFakeTimers();
    const fake = new FakeWebSocket();
    let created = 0;
    const factory = () => {
      created++;
      return fake;
    };
    const mgr = createConnectionManager("ws://test", factory, () => {});

    fake.fireOpen();
    fake.fireClose();

    expect(mgr.state).toBe("reconnecting");

    vi.advanceTimersByTime(1000);
    expect(created).toBe(2);

    vi.useRealTimers();
  });
});
