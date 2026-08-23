import { createStore, reconcile } from "solid-js/store";
import { createSignal } from "solid-js";
import { decodeTemplate } from "../codec/template-decode";
import { log } from "../debug";
import type {
  EventRejection,
  ServerMessage,
  SessionState as SessionStateMsg,
  TemplateUpdate,
} from "../types/protocol";
import type { Template } from "../types/template";

export type SessionStore = {
  sessionId: string;
  mode: string;
  revision: number;
  tree: Template | null;
  generationId: string | null;
  connected: boolean;
  error: string | null;
};

export type SessionStoreApi = {
  store: SessionStore;
  setConnected: (connected: boolean) => void;
  applyMessage: (msg: ServerMessage) => void;
  reset: () => void;
  error: () => string | null;
  clearError: () => void;
};

const initialState: SessionStore = {
  sessionId: "",
  mode: "",
  revision: 0,
  tree: null,
  generationId: null,
  connected: false,
  error: null,
};

export function createSessionStore(): SessionStoreApi {
  const [store, setStore] = createStore<SessionStore>({ ...initialState });
  const [errorSignal, setErrorSignal] = createSignal<string | null>(null);

  const applySessionState = (msg: SessionStateMsg) => {
    log("store", `session_state session=${msg.session_id} rev=${msg.revision} gen=${msg.generation_id ?? "none"}`);
    setStore("sessionId", msg.session_id);
    setStore("mode", msg.mode);
    setStore("revision", msg.revision);
    setStore("generationId", msg.generation_id ?? null);
    if (msg.tree !== undefined) {
      const decoded = decodeTemplate(msg.tree);
      if (decoded.ok) {
        log("store", `session_state tree decoded kind=${decoded.value.kind}`);
        setStore("tree", reconcile(decoded.value, { key: "id" }));
      } else {
        log("store", `session_state tree decode FAILED: ${decoded.error.field}: ${decoded.error.message}`);
        setError(`Failed to decode tree: ${decoded.error.field}: ${decoded.error.message}`);
      }
    }
  };

  const applyTemplateUpdate = (msg: TemplateUpdate) => {
    log("store", `template_update session=${msg.session_id} rev=${msg.revision}`);
    setStore("sessionId", msg.session_id);
    setStore("revision", msg.revision);
    const decoded = decodeTemplate(msg.tree);
    if (decoded.ok) {
      log("store", `template_update tree decoded kind=${decoded.value.kind}`);
      setStore("tree", reconcile(decoded.value, { key: "id" }));
    } else {
      log("store", `template_update tree decode FAILED: ${decoded.error.field}: ${decoded.error.message}`);
      setError(`Failed to decode tree: ${decoded.error.field}: ${decoded.error.message}`);
    }
  };

  const applyEventRejection = (msg: EventRejection) => {
    log("store", `event_rejection session=${msg.session_id} event=${msg.event_id} reason=${msg.reason}`);
    setError(`Event rejected (${msg.event_id}): ${msg.reason}`);
  };

  const setError = (message: string) => {
    setStore("error", message);
    setErrorSignal(message);
  };

  const applyMessage = (msg: ServerMessage) => {
    switch (msg.kind) {
      case "session_state": applySessionState(msg); break;
      case "template_update": applyTemplateUpdate(msg); break;
      case "event_rejection": applyEventRejection(msg); break;
    }
  };

  return {
    store,
    setConnected: (connected: boolean) => setStore("connected", connected),
    applyMessage,
    reset: () => {
      setStore(reconcile({ ...initialState }, { key: "id" }));
      setErrorSignal(null);
    },
    error: errorSignal,
    clearError: () => {
      setStore("error", null);
      setErrorSignal(null);
    },
  };
}
