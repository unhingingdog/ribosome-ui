import { describe, it, expect } from "vitest";
import { createRoot } from "solid-js";
import { createSessionStore } from "../src/store/session-store";
import type { ServerMessage } from "../src/types/protocol";

const emptyTree = '{"kind":"container","id":"root","direction":"Vertical","children":[]}';
const treeWithChildren = JSON.stringify({
  kind: "container",
  id: "root",
  direction: "Vertical",
  children: [
    { kind: "text", id: "t1", text_type: "Paragraph", value: "Hello" },
    { kind: "text", id: "t2", text_type: "Paragraph", value: "World" },
  ],
});
const treeWithUpdatedChild = JSON.stringify({
  kind: "container",
  id: "root",
  direction: "Vertical",
  children: [
    { kind: "text", id: "t1", text_type: "Paragraph", value: "Updated" },
    { kind: "text", id: "t2", text_type: "Paragraph", value: "World" },
  ],
});

describe("createSessionStore", () => {
  it("starts with empty state", () => {
    createRoot((dispose) => {
      const { store } = createSessionStore();
      expect(store.sessionId).toBe("");
      expect(store.revision).toBe(0);
      expect(store.tree).toBeNull();
      expect(store.connected).toBe(false);
      dispose();
    });
  });

  it("applies session_state message", () => {
    createRoot((dispose) => {
      const { store, applyMessage } = createSessionStore();
      const msg: ServerMessage = {
        kind: "session_state",
        session_id: "rs-1",
        mode: "ui",
        revision: 1,
        tree: emptyTree,
      };
      applyMessage(msg);
      expect(store.sessionId).toBe("rs-1");
      expect(store.mode).toBe("ui");
      expect(store.revision).toBe(1);
      expect(store.tree).not.toBeNull();
      if (store.tree) expect(store.tree.kind).toBe("container");
      dispose();
    });
  });

  it("applies session_state with generation_id", () => {
    createRoot((dispose) => {
      const { store, applyMessage } = createSessionStore();
      applyMessage({
        kind: "session_state",
        session_id: "rs-1",
        mode: "ui",
        revision: 3,
        tree: emptyTree,
        generation_id: "msg-1",
      });
      expect(store.generationId).toBe("msg-1");
      dispose();
    });
  });

  it("applies template_update and updates revision", () => {
    createRoot((dispose) => {
      const { store, applyMessage } = createSessionStore();
      applyMessage({
        kind: "session_state",
        session_id: "rs-1",
        mode: "ui",
        revision: 1,
        tree: emptyTree,
      });
      applyMessage({
        kind: "template_update",
        session_id: "rs-1",
        revision: 2,
        tree: treeWithChildren,
      });
      expect(store.revision).toBe(2);
      expect(store.tree).not.toBeNull();
      if (store.tree && store.tree.kind === "container") {
        expect(store.tree.children).toHaveLength(2);
      }
      dispose();
    });
  });

  it("preserves identity of unchanged child nodes via reconcile", () => {
    createRoot((dispose) => {
      const { store, applyMessage } = createSessionStore();

      applyMessage({
        kind: "template_update",
        session_id: "rs-1",
        revision: 1,
        tree: treeWithChildren,
      });

      const child0Before = store.tree?.kind === "container" ? store.tree.children[0] : null;
      const child1Before = store.tree?.kind === "container" ? store.tree.children[1] : null;

      applyMessage({
        kind: "template_update",
        session_id: "rs-1",
        revision: 2,
        tree: treeWithUpdatedChild,
      });

      const child0After = store.tree?.kind === "container" ? store.tree.children[0] : null;
      const child1After = store.tree?.kind === "container" ? store.tree.children[1] : null;

      expect(child0Before).toBeDefined();
      expect(child0After).toBeDefined();

      if (child0Before && child0After && child0Before.kind === "text" && child0After.kind === "text") {
        expect(child0After.value).toBe("Updated");
        expect(child0Before.value).toBe("Hello");
      }

      if (child1Before && child1After) {
        expect(child1Before).toStrictEqual(child1After);
      }

      dispose();
    });
  });

  it("applies event_rejection and sets error", () => {
    createRoot((dispose) => {
      const { store, applyMessage, error } = createSessionStore();
      applyMessage({
        kind: "event_rejection",
        session_id: "rs-1",
        event_id: "evt-1",
        reason: "stale_revision",
      });
      expect(store.error).not.toBeNull();
      expect(store.error).toContain("stale_revision");
      expect(error()).not.toBeNull();
      dispose();
    });
  });

  it("clearError resets error state", () => {
    createRoot((dispose) => {
      const { store, applyMessage, clearError, error } = createSessionStore();
      applyMessage({
        kind: "event_rejection",
        session_id: "rs-1",
        event_id: "evt-1",
        reason: "duplicate_event_id",
      });
      expect(error()).not.toBeNull();
      clearError();
      expect(store.error).toBeNull();
      expect(error()).toBeNull();
      dispose();
    });
  });

  it("setConnected updates connected state", () => {
    createRoot((dispose) => {
      const { store, setConnected } = createSessionStore();
      expect(store.connected).toBe(false);
      setConnected(true);
      expect(store.connected).toBe(true);
      dispose();
    });
  });

  it("reset clears all state", () => {
    createRoot((dispose) => {
      const { store, applyMessage, reset } = createSessionStore();
      applyMessage({
        kind: "session_state",
        session_id: "rs-1",
        mode: "ui",
        revision: 5,
        tree: emptyTree,
      });
      reset();
      expect(store.sessionId).toBe("");
      expect(store.revision).toBe(0);
      expect(store.tree).toBeNull();
      dispose();
    });
  });
});
