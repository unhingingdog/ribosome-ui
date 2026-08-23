export type LogLevel = "info" | "warn" | "error";

export interface LogEntry {
  level: LogLevel;
  category: string;
  message: string;
  sessionId?: string;
  callId?: string;
}

export type LogSink = (entry: LogEntry) => void;

const noop: LogSink = () => {};

let currentSink: LogSink = noop;

export function setLogSink(sink: LogSink): void {
  currentSink = sink;
}

export function resetLogSink(): void {
  currentSink = noop;
}

export function log(
  level: LogLevel,
  category: string,
  message: string,
  meta?: { sessionId?: string; callId?: string },
): void {
  currentSink({
    level,
    category,
    message,
    sessionId: meta?.sessionId,
    callId: meta?.callId,
  });
}

export function logInfo(
  category: string,
  message: string,
  meta?: { sessionId?: string; callId?: string },
): void {
  log("info", category, message, meta);
}

export function logWarn(
  category: string,
  message: string,
  meta?: { sessionId?: string; callId?: string },
): void {
  log("warn", category, message, meta);
}

export function logError(
  category: string,
  message: string,
  meta?: { sessionId?: string; callId?: string },
): void {
  log("error", category, message, meta);
}

export function createStderrSink(): LogSink {
  return (entry: LogEntry) => {
    const parts: string[] = [
      `[ribosome:${entry.level}]`,
      entry.category,
      entry.message,
    ];
    if (entry.sessionId) parts.push(`session=${entry.sessionId}`);
    if (entry.callId) parts.push(`call=${entry.callId}`);
    process.stderr.write(parts.join(" ") + "\n");
  };
}
