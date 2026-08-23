import { describe, it, expect, beforeEach, afterEach } from "vitest";
import {
  log,
  logInfo,
  logWarn,
  logError,
  setLogSink,
  resetLogSink,
  createStderrSink,
  type LogEntry,
} from "../src/diagnostics.js";

describe("diagnostics", () => {
  let entries: LogEntry[] = [];

  beforeEach(() => {
    entries = [];
    setLogSink((entry) => entries.push(entry));
  });

  afterEach(() => {
    resetLogSink();
  });

  it("logs info with category and message", () => {
    logInfo("kickoff", "starting");
    expect(entries).toHaveLength(1);
    expect(entries[0].level).toBe("info");
    expect(entries[0].category).toBe("kickoff");
    expect(entries[0].message).toBe("starting");
  });

  it("logs warn with session metadata", () => {
    logWarn("harness", "disconnected", { sessionId: "oc-1" });
    expect(entries[0].level).toBe("warn");
    expect(entries[0].sessionId).toBe("oc-1");
  });

  it("logs error with call metadata", () => {
    logError("kickoff", "no pending", { callId: "call-1" });
    expect(entries[0].level).toBe("error");
    expect(entries[0].callId).toBe("call-1");
  });

  it("log function accepts all levels", () => {
    log("info", "a", "msg-a");
    log("warn", "b", "msg-b");
    log("error", "c", "msg-c");
    expect(entries.map((e) => e.level)).toEqual(["info", "warn", "error"]);
  });

  it("noop sink by default does not throw", () => {
    resetLogSink();
    expect(() => logInfo("test", "hello")).not.toThrow();
  });

  it("createStderrSink writes to stderr without throwing", () => {
    const sink = createStderrSink();
    expect(() =>
      sink({
        level: "info",
        category: "test",
        message: "stderr test",
        sessionId: "s1",
      }),
    ).not.toThrow();
  });
});
