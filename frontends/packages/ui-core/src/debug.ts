const enabled = (() => {
  try {
    const g = globalThis as Record<string, unknown>;
    const p = g.process as Record<string, Record<string, string>> | undefined;
    if (p?.env?.RIBOSOME_DEBUG === "1") return true;
  } catch {
    /* not in Node */
  }
  try {
    const g = globalThis as Record<string, unknown>;
    const ls = g.localStorage as Storage | undefined;
    if (ls?.getItem("RIBOSOME_DEBUG") === "1") return true;
  } catch {
    /* not in browser */
  }
  return false;
})();

export function log(category: string, message: string): void {
  if (enabled) {
    const ts = new Date().toISOString().slice(11, 23);
    const line = `[${ts}] [${category}] ${message}`;
    if (typeof console !== "undefined" && console.error) {
      console.error(line);
    }
  }
}

export const debugEnabled = enabled;
