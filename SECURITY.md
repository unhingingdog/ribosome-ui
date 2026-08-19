# Security audit

## Scope

Dream's Codex process boundary, streamed-template handling, WebSocket protocol, and Ratatui rendering path.

## Release blockers

### WebSocket sessions have no authentication or ownership binding

`/v1/tui` accepts `newSession` and `resumeSession` without credentials. Session IDs are sequential (`session-1`, `session-2`, …), and a client that knows an ID can resume its session.

Do not bind Dream beyond loopback until authentication, unguessable session IDs, and per-session authorization are implemented.

### Stream and connection resources are unbounded

Codex deltas accumulate in Telomere buffers. Dream also has no configured maximum WebSocket message size, active-session limit, connection limit, generation duration, or output-token/delta budget.

Add explicit limits and cancellation on limit breaches before exposing Dream to untrusted clients.

### Generated strings reach the terminal without a control-character policy

Validated template structure does not constrain text, labels, option values, or IDs. Those strings are rendered by Ratatui without an application-level control-character filter.

Define and test a terminal-content policy before accepting model output from an untrusted source.

### The executable accepts arbitrary WebSocket URLs

The TUI CLI accepts a caller-provided URL and permits plain `ws://`. Treat the TUI as a local-development client until it enforces an approved endpoint policy and uses authenticated TLS for non-local deployment.

## Existing controls

- Dream, not the TUI, parses, validates, and reconciles generated templates.
- Failed template deserialization preserves the last valid tree.
- TUI events are semantic component events with session and revision checks.
- Codex thread requests set approval policy to `never` and sandbox policy to `read-only`.
- The Codex child stderr capture is bounded.

## Functional release gate

`Dream_server.Bootstrap.run` currently serves only `/health`; it does not mount `Dream_server.Websocket.route`. The documented TUI smoke command therefore requires a host application that mounts `/v1/tui`.

Before release, mount the WebSocket route in the Dream application and run the live smoke test against a loopback-only server.
