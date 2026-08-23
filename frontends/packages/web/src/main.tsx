import { render } from "solid-js/web";
import {
  UiTransport,
  createSessionStore,
  createEventDispatch,
} from "@ribosome/ui-core";
import { App } from "./app";
import "./style.css";

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
