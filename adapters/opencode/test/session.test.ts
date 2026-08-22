import { describe, it, expect } from "vitest";
import {
  createSessionStore,
  addSession,
  findSession,
  removeSession,
  markKickoffComplete,
  markHarnessConnected,
  updateRevision,
  generateNonce,
} from "../src/session.js";

describe("session store", () => {
  it("adds and finds sessions", () => {
    const store = createSessionStore();
    const s = addSession(store, "oc-1", "nonce-abc");

    expect(s.sessionId).toBe("oc-1");
    expect(s.nonce).toBe("nonce-abc");
    expect(s.pendingKickoff).toBe(true);
    expect(s.harnessConnected).toBe(false);

    const found = findSession(store, "oc-1");
    expect(found).toBe(s);
  });

  it("returns undefined for missing session", () => {
    const store = createSessionStore();
    expect(findSession(store, "nope")).toBeUndefined();
  });

  it("removes sessions", () => {
    const store = createSessionStore();
    addSession(store, "oc-1", "n1");

    expect(removeSession(store, "oc-1")).toBe(true);
    expect(findSession(store, "oc-1")).toBeUndefined();
    expect(removeSession(store, "oc-1")).toBe(false);
  });

  it("marks kickoff complete", () => {
    const store = createSessionStore();
    addSession(store, "oc-1", "n1");

    const s = markKickoffComplete(store, "oc-1");
    expect(s?.pendingKickoff).toBe(false);
  });

  it("marks harness connected", () => {
    const store = createSessionStore();
    addSession(store, "oc-1", "n1");

    const s = markHarnessConnected(store, "oc-1");
    expect(s?.harnessConnected).toBe(true);
  });

  it("updates revision", () => {
    const store = createSessionStore();
    addSession(store, "oc-1", "n1");

    const s = updateRevision(store, "oc-1", 42);
    expect(s?.treeRevision).toBe(42);
  });

  it("generateNonce returns oc- prefix", () => {
    const n = generateNonce();
    expect(n.startsWith("oc-")).toBe(true);
    expect(n.length).toBeGreaterThan(4);
  });
});
