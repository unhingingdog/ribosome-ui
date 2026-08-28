export type LogLevel = "info" | "warn" | "error";

export interface LogEntry {
  readonly level: LogLevel;
  readonly category: string;
  readonly message: string;
  readonly ocId?: string;
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

export function writeLog(level: LogLevel, category: string, message: string, ocId?: string): void {
  currentSink({ level, category, message, ocId });
}

export function logInfo(category: string, message: string, ocId?: string): void {
  writeLog("info", category, message, ocId);
}

export function logWarn(category: string, message: string, ocId?: string): void {
  writeLog("warn", category, message, ocId);
}

export function logError(category: string, message: string, ocId?: string): void {
  writeLog("error", category, message, ocId);
}

export function createStderrSink(): LogSink {
  return (entry: LogEntry) => {
    const parts: string[] = [
      `[ribosome:${entry.level}]`,
      entry.category,
      entry.message,
    ];
    if (entry.ocId) parts.push(`session=${entry.ocId}`);
    process.stderr.write(parts.join(" ") + "\n");
  };
}
