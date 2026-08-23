# Ribosome Protocols

Protocol messages are versioned (current: `0.0.0`). Field names and enum strings are locked by contract fixtures in `protocol-fixtures/`. Both OCaml server and TypeScript adapter decode the same fixtures in CI — no silent drift.

## Protocol version

Shared across all protocols. Defined once in `Harness_protocol.version` and `Ui_protocol.version`. Fixture tests in both languages assert the constant matches `protocol-fixtures/harness.json` → `version`.

---

## MCP control protocol (stdio)

Ribosome runs as an MCP server over stdio. Supported subset:

| Method | Direction | Reply |
|---|---|---|
| `initialize` | harness → server | `initialize_result` |
| `notifications/initialized` | harness → server | (notification, no reply) |
| `ping` | harness → server | `{}` |
| `tools/list` | harness → server | `[{ name: "start", ... }]` |
| `tools/call` → `start` | harness → server | structured content + tool result |

### `tools/call start`

```
Request params:
  {
    "mode": "ui",          // default
    "session_id": "rs-1",
    "harness_session_id": "oc-1",
    "nonce": "abc123"
  }

Response result:
  {
    "session_id": "rs-1",
    "skill_content": "..."   // mode's SKILL.md body
  }
```

The adapter injects `harness_session_id` and `nonce` before the harness sends `tools/call`. These are opaque to the harness.

---

## Harness protocol (WebSocket `/v1/harness`)

The adapter opens this WebSocket after receiving the MCP start nonce.

### Messages (server → adapter)

```
userTurn:
  {"session_id": "rs-1", "tree": "{...json...}", "event": "null"}
```
Tree is the full authoritative template JSON. Event is the semantic event that triggered the turn (`null` on initial attach).

```
ack:
  {"session_id": "rs-1", "generation_id": "msg-1", "seq": 3}
```
Acknowledges receipt of a delta.

```
rejection:
  {"session_id": "rs-1", "reason": "invalid_session"}
```
Reasons: `invalid_session`, `invalid_generation`, `invalid_sequence`, `malformed_payload`.

### Messages (adapter → server)

```
attach:
  {"session_id": "rs-1", "harness_session_id": "oc-1", "nonce": "abc123"}
```
First message after WebSocket open. Authenticates with the nonce from `tools/call start`.

```
delta:
  {"session_id": "rs-1", "generation_id": "msg-1", "seq": 0, "content": "..."}
```
One per native assistant token. Seq starts at 0 per generation.

```
generation_completed:
  {"session_id": "rs-1", "generation_id": "msg-1"}
```

```
generation_failed:
  {"session_id": "rs-1", "generation_id": "msg-1", "reason": "timeout"}
```
Reason is optional.

### Sequence rules

```
gen_id=msg-1:  delta seq=0  →  delta seq=1  →  delta seq=2  →  completed
gen_id=msg-2:  delta seq=0  →  delta seq=1  →  ...
```

Sequences reset per generation. A delta with mismatched generation ID or out-of-order seq returns a `rejection`. The generation ID must match the active generation on the session.

### Complete flow

```
  Adapter              Server
  ───────              ──────
  │ attach(nonce) ────►│ authenticate, start session
  │                     │
  │ delta(gen=1,seq=0)─►│ Telomere.feed → decode → reconcile → broadcast
  │ delta(gen=1,seq=1)─►│ ...
  │ delta(gen=1,seq=2)─►│ ...
  │ completed(gen=1)───►│ commit final revision
  │                     │
  │◄── userTurn ────────│ (on submit from UI)
  │                     │
  │ delta(gen=2,seq=0)─►│ new generation
  │ delta(gen=2,seq=1)─►│ reconcile preserves prior tree
  │ completed(gen=2)───►│
```

---

## UI protocol (WebSocket `/v1/ui`)

Clients attach with a session nonce from the MCP start result.

### Messages (server → client)

```
sessionState:
  {"session_id":"rs-1","mode":"ui","revision":5,"tree":"{...json...}",
   "generation_id":"msg-1"|null}
```
Sent on attach and reconnect. `tree` is `null` before the first commit.

```
templateUpdate:
  {"session_id":"rs-1","revision":6,"tree":"{...json...}"}
```
Every committed revision. Includes the full tree — clients diff locally.

```
eventRejection:
  {"session_id":"rs-1","event_id":"evt-5","reason":"stale_revision"}
```
Reasons: `stale_revision`, `duplicate_event_id`.

### Messages (client → server)

```
attach:
  {"session_id":"rs-1"}                    // fresh attach
  {"session_id":"rs-1","revision":3}       // reconnect from known rev
```

```
componentEvent:
  {"session_id":"rs-1","revision":5,"event_id":"evt-1",
   "target_id":"btn1","kind":"click"}
  
  {"session_id":"rs-1","revision":5,"event_id":"evt-2",
   "target_id":"inp1","kind":"change","value":"hello"}
  
  {"session_id":"rs-1","revision":5,"event_id":"evt-3",
   "target_id":"form1","kind":"submit"}
```

`value` on change is `string` or `int`. On click/submit it is `null`.

```
cancel:
  {"session_id":"rs-1"}
```
Requests cancellation of the active generation.

```
disconnect:
  {"session_id":"rs-1"}
```
Clean disconnect. The server prunes the connection.

### Revision and event-ID rules

- `revision` in `componentEvent` must match the client's last known revision. Mismatch → `eventRejection(stale_revision)`.
- `event_id` must be unique within the session's bounded recent window. Duplicate → `eventRejection(duplicate_event_id)`.
- `click` and `submit` produce one `userTurn` to the harness. `change` applies locally and broadcasts only.
- Reconnect with a known `revision` resends `sessionState`; attach without revision gets the current state regardless.

---

## Writing a new harness adapter

To add a harness adapter for Codex, Pi, or any other agent host:

```
  Host SDK               Adapter (you write)          Ribosome
  ────────               ──────────────────           ────────
  │ MCP node spawning ──►│ intercept tools/call ◄───── MCP stdio │
  │                       │ inject nonce, hs_id                       │
  │                       │ open WS /v1/harness ─────► harness WS    │
  │                       │                                    │
  │ streaming delta ────►│ forward as delta ──────────► Telomere     │
  │ completion ─────────►│ forward as completed ──────► session      │
  │ error ──────────────►│ forward as failed ─────────►              │
  │                       │                                    │
  │                       │◄── userTurn(tree,event) ──── submit      │
  │ new turn(tree) ◄─────│ translate to host API                     │
```

### Required hooks

1. **Intercept `tools/call`**: Inject `harness_session_id` and `nonce` params before the harness sends the request. The OpenCode adapter does this via `tool.execute.before`.

2. **Open harness WebSocket**: After `start` returns, connect to `/v1/harness` and send `attach` with the nonce.

3. **Forward deltas**: Map host-native streaming events to `delta` messages. One delta per atomic text fragment. Never batch. Seq must be monotonic.

4. **Forward terminal events**: Map host completion → `generation_completed`, host error → `generation_failed`.

5. **Apply user turns**: On `userTurn`, deserialize the tree, format it for the host's injection API, and start the next turn. The OpenCode adapter wraps the tree in `[ribosome-tree]...[/ribosome-tree]` tags with the semantic event in `[ribosome-event]...[/ribosome-event]`.

### Types you need

```typescript
// Harness protocol messages (adapter → server)
type Attach   = { kind: "attach", session_id, harness_session_id, nonce }
type Delta    = { kind: "delta", session_id, generation_id, seq, content }
type Completed = { kind: "generation_completed", session_id, generation_id }
type Failed   = { kind: "generation_failed", session_id, generation_id, reason? }

// Harness protocol messages (server → adapter)
type UserTurn = { kind: "user_turn", session_id, tree, event }
type Ack      = { kind: "ack", session_id, generation_id, seq }
type Rejection = { kind: "rejection", session_id, reason }

// UI protocol (for native clients, not adapters)
type ComponentEvent = { kind: "component_event", session_id, revision,
                        event_id, target_id, component_kind, value? }
type SessionState   = { kind: "session_state", session_id, mode,
                        revision, tree, generation_id }
type TemplateUpdate = { kind: "template_update", session_id, revision, tree }
```

The authoritative shapes live in `protocol-fixtures/harness.json` and `protocol-fixtures/ui.json`. Decode them in your adapter tests to prevent drift.

### Session management

```
  start ──► session created (mode, skill bundle)
  attach ──► harness WebSocket authenticates with nonce
  deltas ──► generation streams, tree updates
  submit ──► userTurn emitted, new generation awaits
  disconnect ──► socket closes
  reconnect ──► attach with nonce again, sessionState with known revision
```

The session registry (`Session_registry`) maps `session_id` → `harness_session_id` → `mode_id`. Runtimes (`Harness_runtime`, `Ui_runtime`) hold actual `Ribosome.Session.t` values keyed by `session_id`.

---

## Writing a new UI client

Native, web, and TUI clients all consume the same UI protocol over `/v1/ui` WebSocket:

```
  Client                     Server
  ──────                     ──────
  │ connect ────────────────►│
  │◄── sessionState ─────────│  (full tree snapshot)
  │◄── templateUpdate ───────│  (each revision, full tree)
  │                           │
  │──► ComponentEvent ──────►│  (user actions)
  │◄── eventRejection ───────│  (if stale/duplicate)
```

### To implement

1. Connect to `ws://<host>/v1/ui` with the session ID from the `start` response.
2. Send `attach`: `{"kind":"attach","session_id":"rs-1",["revision":3]}`.
3. Render the tree from `sessionState` or the latest `templateUpdate`.
4. On user interaction, send `componentEvent` with the client's known revision.
5. Handle `eventRejection` by re-fetching state and retrying.
6. On reconnect, send `attach` with the last known revision; server re-acks or sends fresh state.

The tree is standard JSON matching `Template.encode`. Decode into your platform's UI widget hierarchy. Root is always a `Container` — use `direction` for layout.
