import { render } from "@opentui/solid";
import {
  UiTransport,
  createSessionStore,
  createEventDispatch,
} from "@ribosome/ui-core";
import { TuiApp } from "./app";

const sessionId = process.argv[2] ?? "rs-1";
const serverHost = process.env.RIBOSOME_SERVER_HOST ?? "localhost";
const serverPort = process.env.RIBOSOME_SERVER_PORT ?? "8787";
const wsUrl = `ws://${serverHost}:${serverPort}/v1/ui?session_id=${sessionId}`;

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

await render(
  () => <TuiApp transport={transport} session={session} dispatch={dispatch} />,
  {
    exitOnCtrlC: true,
  },
);
