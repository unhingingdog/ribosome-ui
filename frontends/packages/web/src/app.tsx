import { Show } from "solid-js";
import { createStore } from "solid-js/store";
import {
  createSessionStore,
  createEventDispatch,
  createBoundRenderer,
  type UiTransport,
  type TransportState,
  type ServerMessage,
} from "@ribosome/ui-core";
import { webComponents } from "./components";

export function App(props: {
  transport: UiTransport;
  session: ReturnType<typeof createSessionStore>;
  dispatch: ReturnType<typeof createEventDispatch>;
}) {
  const { session, dispatch } = props;
  const renderer = createBoundRenderer(webComponents, dispatch.sendComponentEvent);

  const [uiState, setUiState] = createStore<{
    transportState: TransportState;
  }>({
    transportState: "disconnected",
  });

  props.transport.setHandlers({
    onMessage: (msg: ServerMessage) => {
      session.applyMessage(msg);
    },
    onStateChange: (state: TransportState) => {
      setUiState("transportState", state);
      session.setConnected(state === "connected");
    },
  });

  props.transport.connect();

  const statusText = () => {
    switch (uiState.transportState) {
      case "connected": return "Connected";
      case "connecting": return "Connecting…";
      case "reconnecting": return "Reconnecting…";
      case "disconnected": return "Disconnected";
      case "shutdown": return "Shutdown";
    }
  };

  const statusClass = () => {
    if (uiState.transportState === "connected") return "connected";
    if (uiState.transportState === "disconnected" || uiState.transportState === "shutdown") return "disconnected";
    return "connecting";
  };

  const tree = () => session.store.tree;

  return (
    <div>
      <div class="status-bar">
        <span class={`status-dot ${statusClass()}`} />
        <span>{statusText()}</span>
        <span class="status-revision">rev {session.store.revision}</span>
        <Show when={session.store.generationId}>
          <span class="status-generation">generating…</span>
        </Show>
      </div>

      <Show when={session.error()}>
        <div class="error-toast">{session.error()}</div>
      </Show>

      <Show when={tree()} fallback={<div>Waiting for session…</div>}>
        <div class="tree-container">
          {renderer(tree()!)}
        </div>
      </Show>
    </div>
  );
}
