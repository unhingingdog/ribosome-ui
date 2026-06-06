import React from "react";
import ReactDOM from "react-dom/client";

import "./index.css";
import { App } from "./App";

// Verbose debug logging for the demo: lights up both the JS adapter `debug()`
// and the OCaml engine `Utils.Log` (both read window.__DEBUG__).
declare global {
  interface Window {
    __DEBUG__?: number;
  }
}
window.__DEBUG__ = 2;

ReactDOM.createRoot(document.getElementById("root")!).render(
  <App />,
);
