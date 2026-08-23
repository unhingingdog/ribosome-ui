import { Show, For } from "solid-js";
import { createStore } from "solid-js/store";
import {
  createSessionStore,
  createEventDispatch,
  createBoundRenderer,
  type UiTransport,
  type TransportState,
  type ServerMessage,
} from "@ribosome/ui-core";
import { tuiComponents } from "./components";

export function TuiApp(props: {
  transport: UiTransport;
  session: ReturnType<typeof createSessionStore>;
  dispatch: ReturnType<typeof createEventDispatch>;
}) {
  const { session, dispatch } = props;
  const renderer = createBoundRenderer(tuiComponents, dispatch.sendComponentEvent);

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
      case "connected": return "● Connected";
      case "connecting": return "○ Connecting…";
      case "reconnecting": return "○ Reconnecting…";
      case "disconnected": return "○ Disconnected";
      case "shutdown": return "○ Shutdown";
    }
  };

  const statusColor = () => {
    if (uiState.transportState === "connected") return "green";
    if (uiState.transportState === "disconnected" || uiState.transportState === "shutdown") return "red";
    return "yellow";
  };

  const tree = () => session.store.tree;

  return (
    <box flexDirection="column" height="100%">
      <box border={true} borderStyle="single" borderColor={statusColor()} padding={1}>
        <text fg={statusColor()}>{statusText()}</text>
        <text fg="gray"> │ rev {session.store.revision}</text>
        <Show when={session.store.generationId}>
          <text fg="blue"> │ generating…</text>
        </Show>
      </box>

      <Show when={session.error()}>
        <box border={true} borderColor="red" padding={1}>
          <text fg="red">{session.error()}</text>
        </box>
      </Show>

      <Show
        when={tree()}
        fallback={
          <box flexGrow={1} alignItems="center" justifyContent="center">
            <text fg="gray">Waiting for session…</text>
          </box>
        }
      >
        <box flexGrow={1} flexDirection="column" padding={1}>
          {renderer(tree()!)}
        </box>
      </Show>
    </box>
  );
}
