import { render } from "solid-js/web";
import {
  UiTransport,
  createSessionStore,
  createEventDispatch,
} from "@ribosome/ui-core";
import { App } from "./app";
import { Templates } from "./templates";
import "./style.css";

const path = window.location.pathname;

if (path === "/templates") {
  render(() => <Templates />, document.getElementById("app")!);
} else {
  const sessionId = new URLSearchParams(window.location.search).get("session_id") ?? "rs-1";
  const wsUrl = `ws://${window.location.hostname}:8787/v1/ui?session_id=${sessionId}`;

  const session = createSessionStore();
  const transport = new UiTransport({
    url: wsUrl,
    sessionId,
    handlers: {
      onMessage: () => {},
      onStateChange: () => {},
    },
  });
  const dispatch = createEventDispatch(session, transport);

  render(
    () => <App transport={transport} session={session} dispatch={dispatch} />,
    document.getElementById("app")!,
  );
}
