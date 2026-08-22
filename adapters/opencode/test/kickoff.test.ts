import { describe, it, expect } from "vitest";
import { createKickoffManager, type PendingKickoff } from "../src/kickoff.js";
import { createSessionStore } from "../src/session.js";

describe("kickoff manager", () => {
  it("records pending kickoff with generated nonce", () => {
    const sessions = createSessionStore();
    const mgr = createKickoffManager(sessions);

    const p = mgr.recordPending("call-1", "oc-session-1");

    expect(p.callID).toBe("call-1");
    expect(p.sessionID).toBe("oc-session-1");
    expect(p.nonce).toMatch(/^oc-/);
    expect(mgr.pendingCount).toBe(1);
    expect(mgr.activeCount).toBe(0);
  });

  it("activates on success and returns attach message", () => {
    const sessions = createSessionStore();
    const mgr = createKickoffManager(sessions);

    const p = mgr.recordPending("call-1", "oc-session-1");
    const attach = mgr.activate("call-1", "rs-1", "ui-nonce-xyz");

    expect(attach).not.toBeNull();
    expect(attach!.kind).toBe("attach");
    expect(attach!.session_id).toBe("rs-1");
    expect(attach!.harness_session_id).toBe("oc-session-1");
    expect(attach!.nonce).toBe(p.nonce);
    expect(mgr.pendingCount).toBe(0);
    expect(mgr.activeCount).toBe(1);
  });

  it("getActive returns the session after activation", () => {
    const sessions = createSessionStore();
    const mgr = createKickoffManager(sessions);

    mgr.recordPending("call-1", "oc-session-1");
    mgr.activate("call-1", "rs-1", "ui-nonce-xyz");

    const active = mgr.getActive("oc-session-1");
    expect(active).not.toBeNull();
    expect(active!.sessionId).toBe("oc-session-1");
    expect(active!.pendingKickoff).toBe(false);
  });

  it("clears pending on failure", () => {
    const sessions = createSessionStore();
    const mgr = createKickoffManager(sessions);

    mgr.recordPending("call-1", "oc-session-1");
    const cleared = mgr.clearPending("call-1");

    expect(cleared).not.toBeNull();
    expect(cleared!.callID).toBe("call-1");
    expect(mgr.pendingCount).toBe(0);
    expect(mgr.activeCount).toBe(0);
  });

  it("returns null when clearing unknown callID", () => {
    const sessions = createSessionStore();
    const mgr = createKickoffManager(sessions);

    expect(mgr.clearPending("nope")).toBeNull();
  });

  it("returns null when activating unknown callID", () => {
    const sessions = createSessionStore();
    const mgr = createKickoffManager(sessions);

    expect(mgr.activate("nope", "rs-1", "ui-nonce")).toBeNull();
  });

  it("clears active session", () => {
    const sessions = createSessionStore();
    const mgr = createKickoffManager(sessions);

    mgr.recordPending("call-1", "oc-session-1");
    mgr.activate("call-1", "rs-1", "ui-nonce-xyz");

    const cleared = mgr.clearActive("oc-session-1");
    expect(cleared).not.toBeNull();
    expect(mgr.activeCount).toBe(0);
    expect(mgr.getActive("oc-session-1")).toBeNull();
  });
});
