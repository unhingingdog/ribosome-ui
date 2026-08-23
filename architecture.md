# Ribosome Architecture

Ribosome turns an agent harness into a generative-UI runtime. An agent calls the MCP `start` tool; the harness forwards raw assistant deltas over a dedicated WebSocket; every delta feeds through Telomere, decodes into a typed template ADT, reconciles by stable ID, and broadcasts revisioned updates to UI clients. User submissions return as a complete semantic event that starts the next harness turn.

```
                  ┌──────────────┐
                  │ Agent Harness │  (OpenCode / Codex / Pi)
                  └──┬────────┬──┘
              MCP    │        │   assistant deltas
            control  │        │
                     ▼        ▼
              ┌──────────┐  ┌──────────┐
              │   MCP    │  │ Harness  │
              │(stdio)   │  │ Stream   │
              └────┬─────┘  └────┬─────┘
                   │             │
                   │   ┌─────────▼──────────┐
                   │   │  Telomere           │
                   │   │  → Decode → Validate│
                   │   │  → Reconcile        │
                   └──►│  → Session          │
                       └─────────┬──────────┘
                                 │ revisioned
                                 │ updates
                          ┌──────▼──────┐
                          │  UI Client  │
                          │ (TUI/Web/   │
                          │  Native)    │
                          └─────────────┘
```

## Invariants

- Every delta feeds through **Telomere**. Nothing batches, debounces, or bypasses token-level streaming.
- `ribosome` owns a **closed OCaml template ADT**. Clients don't define template kinds.
- The core knows nothing about MCP, Dream, WebSockets, or any specific harness.
- MCP is the **control plane**, not the delta transport.
- Submissions are **complete trees**, never token-streamed back.
- The only TypeScript is a **thin harness adapter** (`adapters/opencode/`).

## Packages

```
telomere ──► ribosome ──► ribosome-server
                │                │
                └── yojson ──────┴── dream, lwt, cmdliner
```

| Package | Responsibility | Deps |
|---|---|---|
| `telomere` | Incremental JSON completion | stdlib |
| `ribosome` | Template ADT, codec, validation, reconciliation, session, modes | `telomere`, `yojson` |
| `ribosome-server` | MCP, harness/UI protocols, Dream WebSocket, registry, runtimes | `ribosome`, `yojson`, `lwt`, `dream`, `cmdliner` |
| `adapters/opencode` | Thin TypeScript harness adapter | `@opencode-ai/plugin`, vitest |

All three OCaml packages have warnings-as-errors enabled. Codec helpers (`Codec_decode`, `Codec_encode`, `Codec_error`) are private modules in `ribosome` — accessible only through `Template.CodecError`/`Decode`/`Encode` aliases.

## Planes

### MCP control plane

```
  Harness                    ribosome-server
  ───────                    ──────────────
  │  initialize        ────►  Mcp.process
  │  tools/call start  ────►  session registry
  │                           skill bundle
  │◄─── session nonce   ────  adapter attaches harness WS
```

The harness calls Ribosome as an MCP server over **stdio**. Supported operations: `initialize`, `notifications/initialized`, `ping`, `tools/list`, `tools/call start`. The `start` tool returns session metadata + the mode's skill body as model-visible content, followed by "next response must be raw template JSON only." Deltas are **not** transported through MCP.

### Harness stream plane

```
  Adapter                   ribosome-server
  ───────                   ──────────────
  │  attach(nonce)    ────►  authenticate
  │  delta(gen,seq,text)──►  Telomere.feed → ADT → reconcile
  │  completed(gen)   ────►  commit, broadcast
  │  failed(gen)      ────►  discard
  │◄── userTurn(tree,event)─ submit → next harness turn
```

The adapter authenticates with the start-tool nonce over `/v1/harness` WebSocket, then forwards one delta per native assistant token. Terminal events are `completed` or `failed`. Sequence numbers are per-generation, starting at 0. The server sends `userTurn` back as a complete typed tree + semantic event.

### Core pipeline

```
  delta ──► Telomere.feed ──► Completion(suffix)
              │                    │
              │ Pending            ▼
              │              decode(buffer^suffix)
              │                    │
              │                    ▼
              │              validate invariants
              │                    │
              │                    ▼
              │           reconcile by stable ID
              │                    │
              │                    ▼
              │             commit → revision++
              │                    │
              ▼                    ▼
           wait for             broadcast
           next delta           templateUpdate
```

Every delta feeds `Telomere.Processor.feed`. `Pending` → wait. `Completion suffix` → decode `buffer ^ suffix` into ADT, validate, reconcile. Valid commits increment revision. Decode/validation/reconciliation failures don't mutate state while generation continues. `Corrupted` permanently stops candidates for that processor.

### UI plane

```
  Client                    ribosome-server
  ──────                    ──────────────
  │◄── sessionState  ─────── attach(session)
  │◄── templateUpdate ────── each committed revision
  │──► componentEvent ─────► click / change / submit
  │                           (eventID, baseRevision)
  │◄── eventRejection ────── stale revision / duplicate
```

Click and submit events produce one `userTurn` broadcast. Change events apply locally and broadcast immediately. Stale revisions and duplicate event IDs are rejected. Reconnect from a known revision resends the snapshot.

## Template ADT

The closed OCaml variant maps to JSON `kind` fields. All templates carry a stable `id`.

```
  Template.t
  ├── Text      { id, text_type: Paragraph|H1..H6, value }
  ├── Image     { id, src, alt }
  ├── Badge     { id, label, variant: Neutral|Success|Warning|Error|Info }
  ├── Stat      { id, label, value, secondary? }
  ├── Divider   { id }
  ├── Diagram   { id, diagram_type }
  ├── Code      { id, path, language, line_start, source, highlights[] }
  ├── Container { id, direction: Vertical|Horizontal, children }
  ├── List      { id, ordered?, children }
  └── Submittable { id, button_id }
```

Nested-only templates:
```
  Input    { id, value?: Int|String }     ── only inside Submittable
  Select   { id, options[], value? }      ── only inside Submittable
  Button   { id, label, action: Submit|Navigate|Custom, disabled }
  Tone     { id, text }                   ── only on diagram/code highlights
```

No public `Broken` variant. Decode failures are errors while generation continues.

## Session State

```ocaml
type generation = { id : string; next_seq : int }

type t = {
  id : string;
  mode : Mode.t;
  tree : Template.t option;
  revision : int;
  generation : generation option;
  incremental : Incremental.state;
  recent_event_ids : string list;
}
```

Generation IDs are opaque. Sequences reset per generation at 0. Telomere state resets at generation start while preserving committed tree. Event IDs deduplicate within a bounded window. No harness, MCP, Dream, or WebSocket types in the session record.

## Submission Flow

```
  UI Client          Server             Adapter           Harness
  ─────────          ──────             ───────           ───────
  │ submit(form1, ▲2)│                   │                  │
  │─────────────────►│                   │                  │
  │                   │ reduce event     │                  │
  │                   │ produce tree     │                  │
  │                   │ userTurn(tree,   │                  │
  │                   │   event)         │                  │
  │                   │─────────────────►│                  │
  │                   │                  │ new turn(tree)   │
  │                   │                  │─────────────────►│
  │                   │                  │                  │
  │                   │                  │◄── deltas ───────│
  │                   │◄── delta ────────│                  │
  │                   │                  │                  │
  │◄── templateUpdate │                  │                  │
```

No input is token-streamed back. Full tree + event is one message to the adapter.

## Telomere

The mandatory streaming invariant. All deltas pass through it.

```ocaml
type processor_state
type output = Pending | Completion of string | Corrupted

val create_processor : unit -> processor_state
val feed : processor_state -> string -> output * processor_state
```

`Pending` = mid-token, waiting. `Completion suffix` = `buffer ^ suffix` is valid JSON. `Corrupted` = unrecoverable, no further commits. State is immutable; callers thread the returned state.

## Harness Adapter (OpenCode)

The adapter is at `adapters/opencode/`. It:
- Correlates MCP `start` with native harness sessions via nonce injection
- Forwards one harness delta per native `message.part.delta` event (no batching)
- Maps OpenCode completion/error to `completed`/`failed`
- Decodes `userTurn` and starts the next native turn via plugin hooks
- Manages sessions with reconnect, debounced submission, and structured logging

For adding a **new adapter** (e.g., Codex, Pi), see [PROTOCOL.md](./PROTOCOL.md).

## Future Work

- Additional modes (`code`, `explore`) with distinct skill bundles
- Broader MCP operations beyond `start`
- Additional harness adapters (Codex, Pi)
- Native/web/TUI clients against the versioned UI protocol
