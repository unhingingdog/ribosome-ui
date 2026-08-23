# Ribosome Rebuild Plan

This document breaks the `rebuild/native` branch into features, commits, and subtasks targeting ~100 changed lines per file. Every subtask is a commit-level unit. Acceptance criteria are explicit.

---

## Feature 1: Native Workspace

### Task 1.1: Establish native package workspace

**Goal**: Convert the workspace from Melange to three native packages without breaking legacy directories until they are deleted.

1. Remove `(using melange 0.1)` from `dune-project`. Add `opam` package declarations for `telomere`, `ribosome`, and `ribosome-server` with OCaml 5.2+ requirement.
2. Add `(dirs telomere ribosome ribosome-server adapters skills)` to the root `dune` so Dune ignores legacy `engine/`, `js/`, and `test/` during the transition.
3. Add native library stanzas under `telomere/src/` and `ribosome/src/`.
4. Add private server library and executable stanzas under `ribosome-server/`.
5. Replace `.envrc` with `eval "$(opam env)"` without self-rewrite.
6. Add `.ocamlformat` matching the installed formatter version.
7. Generate `telomere.opam`, `ribosome.opam`, and `ribosome-server.opam`. Keep `ribosome-ui.opam` until legacy deletion.

**Acceptance**: `opam exec -- dune build @all` succeeds without building Melange code.

### Task 1.2: Establish native test infrastructure

1. Add `telomere/test/dune` with Alcotest and QCheck dependencies.
2. Add `ribosome/test/dune` with Alcotest test executables.
3. Add `ribosome-server/test/dune` with Alcotest-Lwt.
4. Add `test_support.ml` per package for readable result assertions.
5. Add one smoke test per package proving Dune discovers each suite.
6. Document `dune build`, `dune runtest`, and `dune fmt` in `README.md`.

**Acceptance**: `opam exec -- dune runtest` discovers all three suites.

---

## Feature 2: Native Telomere

### Task 2.1: Expose a native incremental JSON API

1. Move Telomere implementation files into `telomere/src/`.
2. Rename files to idiomatic lowercase while preserving OCaml module names.
3. Remove all Melange and JSON-library dependencies from the Dune stanza.
4. Add `processor.mli` exposing abstract processor state and `Pending`, `Completion`, and `Corrupted`.
5. Add `telomere.mli` exposing only the supported high-level API.
6. Keep lexer and balancer internals private.
7. Update `telomere/README.md` to show native OCaml usage only.

**Acceptance**: a native test can feed a partial object and receive its completion suffix.

### Task 2.2: Port deterministic Telomere coverage

1. Port complete-object, complete-array, and empty-input tests into `balancer_test.ml`.
2. Port partial object, array, nested, string, number, boolean, and null tests.
3. Port malformed closer, invalid character, and poisoned-state tests.
4. Port key, string, escape, literal, and number chunk-boundary tests.
5. Port every case from `balancer_audit.test.js` in groups under 100 lines.
6. Port processor buffer and completion-shrinking tests into `processor_test.ml`.
7. Use table-driven Alcotest cases rather than repeated bespoke assertions.

**Acceptance**: all behavior covered by the former JS Telomere suites is represented natively.

### Task 2.3: Add Telomere property coverage

1. Add a bounded recursive QCheck generator for `Yojson.Safe.t`.
2. Add a generator that partitions serialized JSON into arbitrary chunks.
3. Assert complete valid JSON finishes with `Completion ""`.
4. Assert every emitted completion produces JSON accepted by `Yojson.Safe.from_string`.
5. Assert final output is invariant under arbitrary chunk partitioning.
6. Assert a corrupted processor remains corrupted for all subsequent input.
7. Configure deterministic seeds in CI while allowing local random seeds.

**Acceptance**: at least 1,000 generated documents pass each fast property.

### Task 2.4: Simplify balancer stack operations

1. Change the closing stack so its head is the active closer.
2. Replace append-plus-reverse pushes and pops with constant-time list operations.
3. Adjust suffix generation to preserve current completion ordering.
4. Remove unused token types and stale Rust-port commentary.
5. Add regression tests for four-level nesting and mixed object/array nesting.
6. Do not change public completion semantics.

**Acceptance**: all deterministic and property tests pass unchanged.

---

## Feature 3: Typed Template Core

### Task 3.1: Define primitive template models

1. Add `template/input.ml` with `Int | String` values.
2. Add `template/select.ml` with options and optional selection.
3. Add `template/button.ml` with `Submit | Navigate | Custom`.
4. Add `template/text.ml` with paragraph and heading variants.
5. Add models for image, badge, stat, and divider in separate files.
6. Keep each record concrete and immutable.
7. Add `.mli` files hiding helper implementation details.

**Acceptance**: primitive values can be constructed without JSON or server dependencies.

### Task 3.2: Define composite and technical templates

1. Add polymorphic `container.ml` with required `Vertical | Horizontal` direction.
2. Add polymorphic `list_template.ml` with optional ordering.
3. Add `submittable.ml` containing only input/select fields and an optional button.
4. Add `diagram.ml` with points, sizes, tones, and typed drawing primitives.
5. Add `code.ml` with source metadata and typed highlights.
6. Add central `template.ml` with the closed recursive variant.
7. Do not add a public `Broken` variant; decoding failures remain errors.
8. Add `id` and `children` helpers covering every variant.

**Acceptance**: the canonical ADT includes the prototype primitive set without extensible variants.

### Task 3.3: Define template metadata registry

1. Add `template_definition.ml` with typed field descriptions.
2. Add one definition value beside each template model.
3. Add `template_registry.ml` containing the canonical ordered set.
4. Distinguish top-level templates from nested-only input/select/button definitions.
5. Add tests ensuring every `Template.t` variant has one registry definition.
6. Add tests ensuring definition kind names are unique.

**Acceptance**: mode skills can be checked against one canonical registry.

### Task 3.4: Add shared JSON codec helpers

1. Add `codec/error.ml` with field path, error category, and message.
2. Add `codec/decode.ml` helpers for objects, fields, options, lists, enums, and integers.
3. Add `codec/encode.ml` helpers for optional fields and object construction.
4. Ensure decoders return `result`; no `failwith` or broad exception swallowing.
5. Add focused helper tests for missing fields, wrong types, and nested error paths.

**Acceptance**: malformed JSON reports the exact failing field path.

### Task 3.5: Encode and decode primitive templates

1. Implement input, select, and button codecs in separate files.
2. Implement text and image codecs.
3. Implement badge, stat, and divider codecs.
4. Accept `value` as the canonical text-content field.
5. Reject unknown enum values explicitly.
6. Add round-trip and malformed-input tests for every primitive.

**Acceptance**: all primitive codecs satisfy `decode (encode value) = Ok value`.

### Task 3.6: Encode and decode composite templates

1. Implement submittable field dispatch.
2. Implement container and list codecs using recursive child callbacks.
3. Implement diagram point and primitive codecs.
4. Implement code highlight and code codecs.
5. Add central template dispatch by `kind`.
6. Add full-tree string encode/decode functions using `Yojson.Safe`.
7. Reject unknown kinds and nested-only kinds at the root.
8. Add one round-trip tree containing every variant.

**Acceptance**: the prototype's representative full tree round-trips natively.

### Task 3.7: Validate template invariants

1. Add traversal over templates, nested controls, buttons, diagram primitives, and code highlights.
2. Reject empty IDs.
3. Reject duplicate IDs across the entire rendered tree.
4. Validate diagram coordinates, dimensions, radii, and polyline length.
5. Validate code line numbers and non-overlapping highlight ranges.
6. Validate selected values against select options.
7. Validate custom and navigation button actions.
8. Return all validation failures where practical.

**Acceptance**: malformed trees never enter incremental or session state.

### Task 3.8: Reconcile templates by stable ID

1. Implement root replacement when IDs match.
2. Recurse only through container and list children.
3. Preserve unaffected siblings and their order.
4. Return an explicit not-found error rather than replacing the root.
5. Add root, child, deeply nested, list, and missing-target tests.
6. Add a test proving fields inside submittables are not patch anchors.

**Acceptance**: patches cannot silently replace an unrelated tree.

### Task 3.9: Apply semantic input to templates

1. Add typed `Click`, `Change`, and `Submit` events.
2. Validate event targets against the current tree.
3. Apply changed input/select values immutably.
4. Apply all submitted values to the targeted submittable.
5. Preserve unrelated nodes and values.
6. Return the full updated tree plus the original semantic event.
7. Add unknown-target, wrong-target-type, and invalid-value tests.

**Acceptance**: a submission produces one authoritative full typed tree.

---

## Feature 4: Incremental UI Runtime

### Task 4.1: Process every generated delta through Telomere

1. Add `incremental.ml` with processor state and last committed tree.
2. Feed every received delta directly to `Telomere.Processor.feed`; never batch.
3. On `Completion suffix`, decode `buffer ^ suffix`.
4. Treat candidate decode/validation failure as no update while generation continues.
5. Reconcile valid candidates against the committed tree.
6. Emit `Updated tree`, `Pending`, `Rejected`, or `Corrupted`.
7. Suppress updates equal to the last committed tree.

**Acceptance**: no generated template path can bypass Telomere.

### Task 4.2: Prove token-level streamed UI updates

1. Feed a text template one character at a time.
2. Assert progressively longer text values become committed updates.
3. Assert incomplete keys and literals preserve the previous tree.
4. Assert partial nested children never delete committed siblings.
5. Assert an unknown patch ID is rejected without changing state.
6. Assert corruption permanently stops candidate commits.

**Acceptance**: tests demonstrate visible updates before generation completion.

### Task 4.3: Add transport-neutral session generation state

1. Add `session.ml` with session ID, mode, tree, revision, and generation state.
2. Represent generation IDs as opaque strings.
3. Require monotonically increasing delta sequence numbers.
4. Add start, delta, complete, fail, and cancel transitions.
5. Reset Telomere state at generation start while preserving the committed tree.
6. Reject deltas for inactive or incorrect generations.
7. Reject duplicate and out-of-order sequence numbers.

**Acceptance**: session state contains no Codex, OpenCode, Dream, or WebSocket types.

### Task 4.4: Add revisioned semantic events

1. Require event ID, session ID, and base revision.
2. Reject stale revisions and duplicate event IDs.
3. Retain a bounded recent-event-ID window.
4. Apply change events locally without starting an agent turn.
5. Produce a user-turn envelope for click and submit events.
6. Include both the full updated tree and semantic event in that envelope.
7. Add stale, duplicate, valid-submit, and valid-click tests.

**Acceptance**: retries cannot submit the same interaction twice.

### Task 4.5: Define mode and skill bundles

1. Add `mode.ml` with mode ID and ordered skill references.
2. Add only the `ui` mode initially.
3. Store the canonical skill at `skills/ribosome/SKILL.md`.
4. Update the skill for container direction, code, and diagram primitives.
5. State that the next assistant response must be raw template JSON only.
6. Add a test checking every registry kind appears in the skill.
7. Add a test rejecting unknown modes.

**Acceptance**: selecting `ui` deterministically returns the Ribosome skill bundle.

---

## Feature 5: Server Protocols

### Task 5.1: Define versioned UI protocol types

1. Add `ui_protocol.ml` with a single protocol version constant.
2. Define UI attach, component event, cancel, and disconnect messages.
3. Define session state, template update, generation lifecycle, and event rejection messages.
4. Carry session ID and revision on every session-specific message.
5. Encode/decode using Yojson with explicit errors.
6. Add JSON fixtures under `protocol-fixtures/`.
7. Add fixture round-trip tests.

**Acceptance**: protocol changes require an explicit version change.

### Task 5.2: Define versioned harness stream protocol

1. Add harness attach with session ID, harness session ID, and channel nonce.
2. Add generation-started, delta, completed, and failed messages.
3. Include generation ID and sequence number on each delta.
4. Define server-to-adapter `userTurn` containing the full tree and event.
5. Define acknowledgement and rejection messages.
6. Add JSON fixtures and codec tests.

**Acceptance**: the harness protocol transports raw deltas without knowing OpenCode types.

### Task 5.3: Implement minimal JSON-RPC framing

1. Add request, response, notification, ID, and error types.
2. Decode JSON-RPC 2.0 requests and notifications.
3. Encode success and error responses.
4. Reject messages containing both result and error.
5. Implement newline-delimited stdio framing.
6. Ensure stdout contains protocol messages only.
7. Add request, notification, malformed JSON, and correlation tests.

**Acceptance**: scripted input produces exact expected JSON-RPC lines.

### Task 5.4: Implement the minimal MCP lifecycle

1. Handle `initialize` for MCP 2025-11-25.
2. Return server information, tool capability, and concise bootstrap instructions.
3. Handle `notifications/initialized`.
4. Handle `ping`.
5. Handle `tools/list`.
6. Return standard method-not-found and invalid-params errors.
7. Reject operational requests before initialization.
8. Add lifecycle ordering tests.

**Acceptance**: MCP Inspector can initialize and list tools over stdio.

### Task 5.5: Implement the MCP start tool

1. Define visible `mode` input, defaulting to `ui`.
2. Accept adapter-injected harness session ID and channel nonce.
3. Reject kickoff when adapter correlation fields are missing.
4. Create a server session and separate UI nonce.
5. Return session metadata as structured content.
6. Return the selected skill body as model-visible content.
7. End with explicit instructions that the next response is raw JSON.
8. Add unknown-mode, duplicate-session, and successful-start tests.

**Acceptance**: an MCP tool result alone gives the model all mode-specific instructions.

### Task 5.6: Add the session registry

1. Add a registry keyed by Ribosome session ID.
2. Add a secondary index from harness session ID.
3. Store UI and harness connection registrations separately.
4. Keep mutation behind a small runtime API.
5. Make IDs/nonces injectable in tests.
6. Add create, find, duplicate, attach, detach, and reconnect tests.

**Acceptance**: concurrent sessions cannot consume one another's deltas or submissions.

### Task 5.7: Route harness protocol into Ribosome sessions

1. Authenticate harness attachment using the nonce injected at kickoff.
2. Map generation-started to `Session.start_generation`.
3. Map every delta to `Session.feed_delta`.
4. Broadcast each committed revision to attached UI clients.
5. Map terminal generation events to session completion/failure.
6. Reject wrong sessions, generations, or sequence numbers.
7. Add reducer tests using a fake broadcast port.

**Acceptance**: one-character harness deltas produce progressive UI protocol updates.

### Task 5.8: Route UI events into sessions

1. Authenticate UI attachment using its session nonce.
2. Send the current snapshot immediately after attachment.
3. Decode and reduce component events.
4. Broadcast local change updates to all UI clients.
5. Send click/submit user turns to the attached harness adapter.
6. Return event rejection without closing a healthy connection.
7. Add reconnect, stale revision, and duplicate event tests.

**Acceptance**: submit produces exactly one complete user-turn message.

### Task 5.9: Add Dream WebSocket transport

1. Add `/v1/harness` and `/v1/ui` routes.
2. Keep route handlers as thin codecs around runtime functions.
3. Enforce loopback binding by default.
4. Set a maximum inbound message size.
5. Close malformed or unauthenticated sockets with policy-error codes.
6. Remove connections on socket termination.
7. Split harness and UI handlers into separate files.
8. Add handler tests with fake runtime ports.

**Acceptance**: Dream remains entirely inside `ribosome-server`.

### Task 5.10: Compose MCP stdio and WebSockets

1. Add Cmdliner options for interface, port, public UI URL, and skill root.
2. Start MCP stdio processing and Dream in one Lwt runtime.
3. Load and validate skill files before reporting readiness.
4. Add `/health` returning version and ready state.
5. Route all logs to stderr.
6. Handle EOF and termination without emitting invalid MCP output.
7. Add an executable smoke test with scripted stdio.

**Acceptance**: `ribosome-server --stdio --port 8787` serves MCP and both WebSocket routes.

---

## Feature 6: OpenCode Adapter

### Task 6.1: Scaffold the harness adapter

1. Add `adapters/opencode/package.json` without React.
2. Add TypeScript configuration and vitest test scripts.
3. Add an adapter configuration type for server URL and MCP tool name.
4. Add a WebSocket connection manager with reconnect and shutdown.
5. Keep session state in a map keyed by OpenCode session ID.
6. Add unit tests using fake WebSocket and plugin contexts.

**Acceptance**: `vitest run` and `tsc --noEmit` pass independently.

### Task 6.2: Correlate MCP kickoff with harness sessions

1. Match only the configured Ribosome `start` MCP tool.
2. In `tool.execute.before`, inject OpenCode session ID and a generated nonce.
3. Record pending kickoff state by tool call ID.
4. In `tool.execute.after`, activate capture only after successful execution.
5. Connect the harness WebSocket using the same injected nonce.
6. Clear pending state on failure or cancellation.
7. Add parallel-session and failed-kickoff tests.

**Acceptance**: two OpenCode sessions receive distinct Ribosome stream channels.

### Task 6.3: Forward assistant deltas without batching

1. Subscribe to OpenCode message-part delta events.
2. Filter by active harness session and text field.
3. Start a generation lazily on the first assistant delta.
4. Use the OpenCode message ID as generation ID.
5. Increment and forward one sequence number per native delta.
6. Do not debounce, concatenate, or delay deltas.
7. Complete on the matching session-idle/message-complete event.
8. Report session errors as generation failures.

**Acceptance**: a fake sequence of five OpenCode deltas produces five harness delta messages.

### Task 6.4: Inject complete UI submissions

1. Decode server `userTurn` messages.
2. Serialize the authoritative tree once.
3. Include the semantic event after the tree for click disambiguation.
4. Start a new OpenCode user turn through the supported session API.
5. Reject messages for inactive or mismatched sessions.
6. Queue at most one submission while OpenCode is busy.
7. Add tests proving values and untouched regions survive injection.

**Acceptance**: no user input is token-streamed back to OpenCode.

### Task 6.5: Package setup and diagnostics

1. Add an OpenCode plugin entry point.
2. Add a sample MCP configuration invoking `ribosome-server`.
3. Document matching server URL/port configuration.
4. Add structured adapter logs without template contents or user values.
5. Add clear diagnostics for missing server, rejected kickoff, and lost stream.
6. Do not modify user-global OpenCode configuration automatically.

**Acceptance**: installation instructions produce a discoverable MCP tool and active adapter.

---

## Feature 7: Vertical Slice

### Task 7.1: Add a protocol-only UI client

1. Add a test client implementing UI attach and message decoding.
2. Track the latest session revision and tree.
3. Generate revision-correct component events.
4. Support reconnect from a known revision.
5. Keep it test-only; do not render terminal or browser components.
6. Add tests against in-memory runtime ports.

**Acceptance**: the client can observe updates and submit a form without UI framework code.

### Task 7.2: Exercise MCP kickoff through streamed rendering

1. Initialize MCP over scripted stdio.
2. Call `tools/list` and `tools/call start`.
3. Attach fake harness and UI clients.
4. Send a complete template one character per delta.
5. Assert multiple pre-completion UI revisions.
6. Complete generation and assert the final typed tree.
7. Assert the returned kickoff content includes the Ribosome skill.

**Acceptance**: this test fails if Telomere is bypassed or deltas are batched.

### Task 7.3: Exercise submission and second generation

1. Submit values from the protocol UI client.
2. Assert the harness receives one full-tree user turn.
3. Start a second generation.
4. Stream a subtree patch one character per delta.
5. Assert reconciliation preserves unaffected root regions.
6. Reconnect the UI client and assert it receives the authoritative tree.

**Acceptance**: the complete two-turn loop runs without Codex, OpenCode, or a real UI.

### Task 7.4: Add OpenCode adapter contract fixtures

1. Store kickoff, delta, completion, and user-turn fixtures under `protocol-fixtures/`.
2. Decode fixtures in both OCaml and TypeScript tests.
3. Assert identical protocol version constants.
4. Assert field names and enum strings match.
5. Fail if either implementation accepts an unsupported version.

**Acceptance**: OCaml and TypeScript cannot drift silently.

---

## Feature 8: Legacy Removal

### Task 8.1: Remove the Melange web implementation

1. Delete `engine/`.
2. Delete `js/`.
3. Delete the legacy root `test/`.
4. Delete `ribosome-ui.opam`.
5. Remove the temporary root Dune directory restriction.
6. Remove Melange, React, fetch, SSE, npm demo, and provider-adapter references.
7. Confirm the OpenCode adapter is the only remaining TypeScript/JavaScript package.

**Acceptance**: repository search finds no `Melange`, `reason-react`, `ReactDOM`, `Fetch`, or old SSE parser references.

### Task 8.2: Tighten native public interfaces

1. Add `.mli` files for every public `ribosome` module.
2. Keep codec helpers and session internals private.
3. Expose only supported Telomere operations.
4. Keep Dream and MCP modules out of the `ribosome` package interface.
5. Remove unused compatibility fields such as legacy text `content` if no persisted-data requirement exists.
6. Enable warnings-as-errors for project libraries.

**Acceptance**: generated documentation shows three coherent package boundaries.

---

## Feature 9: Documentation And Delivery

### Task 9.1: Replace the architecture document

1. Replace the React/Melange architecture diagrams.
2. Document MCP control, harness stream, core pipeline, and UI planes separately.
3. Document Telomere as a mandatory invariant.
4. Document fixed ADT ownership and supported primitives.
5. Document submission flow and complete-tree semantics.
6. Mark code/explore modes and broader MCP operations as future work.

**Acceptance**: every diagram corresponds to implemented modules and protocols.

### Task 9.2: Document protocols and extension points

1. Document MCP `start` request/result.
2. Document harness WebSocket messages.
3. Document UI WebSocket messages.
4. Document revision, sequence, event-ID, and reconnect rules.
5. Document how a new harness adapter maps native deltas.
6. Document how native, web, and TUI targets consume the same typed protocol.

**Acceptance**: a new adapter can be written without reading server internals.

### Task 9.3: Verify native packages and OpenCode adapter

1. Add CI installation for the supported OCaml compiler.
2. Run `dune build @all`, `dune runtest`, and `dune fmt --check`.
3. Run opam lint for all three packages.
4. Run npm install, TypeScript checking, and adapter tests.
5. Cache opam and npm dependencies.
6. Keep randomized property-test seeds visible in failures.

**Acceptance**: CI covers native core, server, protocol fixtures, and adapter.

### Task 9.4: Publish migration and security guidance

1. Explain removal of the npm/React API.
2. Explain that no backward-compatible JS facade remains.
3. Document loopback binding and channel nonce expectations.
4. Warn that harness adapters can inject user turns.
5. Document log redaction requirements.
6. Document supported and unsupported MCP operations.

**Acceptance**: README describes installation, startup, first UI turn, submission, and shutdown.

---

## Verification Gates

After every OCaml task:

```bash
opam exec -- dune build @all
opam exec -- dune runtest
opam exec -- dune fmt
git status --short
git diff --check
```

After every OpenCode adapter task:

```bash
vitest run
npx tsc --noEmit
git diff --check
```

Before completing each feature:

```bash
opam install . --deps-only --with-test
opam exec -- dune build @install
opam exec -- dune runtest
```

Final acceptance requires:

- Three generated opam packages.
- No Melange/web demo code.
- Fixed typed template ADT with code and diagram.
- Native Telomere test parity plus property tests.
- Character-by-character streaming integration test.
- MCP-delivered `ui` skill bundle.
- OpenCode-native delta forwarding.
- WebSocket UI transport with complete submissions.
- Full two-turn protocol test.
- No direct dependency from `ribosome` to MCP, Dream, WebSockets, or OpenCode.

---

## Exploration: Subtree-scoped user turns and MCP tree queries

Instead of sending the full template tree on every `user_turn`, send only the
relevant subtree:

- For **submit**: the submittable node (form + its fields with current values).
- For **click**: the parent container of the clicked button.
- For **change**: no harness message (unchanged from current design).

Add an MCP tool `get_tree` that lets the agent query the current authoritative
tree on demand:

- `get_tree(session_id, node_id?)` — returns the subtree rooted at `node_id`,
  or the full tree if `node_id` is omitted.
- Agent can pull context when it needs broader visibility, rather than always
  receiving the full tree on every interaction.

Benefits to evaluate:

- Token efficiency: a large UI with one form submit doesn't flood the agent
  with irrelevant siblings.
- Agent agency: pull-based context instead of push-only.
- Action clarity: compact `user_turn` with just the touched subtree + event.

Open questions:

- Should `get_tree` return revision metadata so the agent can detect stale
  reads?
- Should changes also be queryable, or remain fire-and-forget on the UI side?
- How does this interact with the queued-submission design in the adapter?

---

## Feature 10: Frontend Clients

### Task 10.1: Monorepo scaffolding

1. Add `frontends/` with pnpm workspace (`pnpm-workspace.yaml`, root `package.json`).
2. Add three packages: `ui-core`, `web`, `tui`.
3. Add `frontends/pnpm-lock.yaml`.
4. Add `**/dist/` to `.gitignore`.

**Acceptance**: `pnpm install` resolves all three packages.

### Task 10.2: ui-core — types and codec

1. Add `types/protocol.ts` (ServerMessage, ClientMessage, Attach, ComponentEvent, etc.).
2. Add `types/template.ts` (all 13 template kinds, Tone, TextType, BadgeVariant, etc.).
3. Add `types/components.ts` (ComponentProps, ComponentMap, EventCallback).
4. Add `codec/decode.ts` (server message decoder with DecodeResult).
5. Add `codec/encode.ts` (client message encoder).
6. Add `codec/template-decode.ts` (full template tree decoder with validation).

**Acceptance**: all types compile, decoders return explicit errors (no exceptions).

### Task 10.3: ui-core — transport, store, renderer

1. Add `transport/websocket.ts` (UiTransport with reconnect, exponential backoff).
2. Add `store/session-store.ts` (Solid createStore + reconcile({key:"id"})).
3. Add `store/event-dispatch.ts` (sendComponentEvent, sendCancel, sendDisconnect).
4. Add `components/template-renderer.tsx` (createRenderer, createBoundRenderer).
5. Add `debug.ts` (RIBOSOME_DEBUG-gated logging).
6. Add `index.ts` barrel.

**Acceptance**: store applies session_state and template_update messages, reconcile diffs by ID.

### Task 10.4: ui-core tests

1. Add decode, encode, template-decode, session-store, contract-fixtures test files.
2. 64 tests covering all decoders, store updates, reconcile behavior, error paths.

**Acceptance**: `pnpm -r test` passes 64 tests.

### Task 10.5: web client

1. Add `web/src/components.tsx` — 13 Solid DOM components + ComponentMap.
2. Add `web/src/app.tsx` — demo app with status bar, error toast, tree renderer.
3. Add `web/src/main.tsx` — entry, reads session_id from URL param.
4. Add `web/src/style.css` — layout, status, error styling.
5. Add `vite.config.ts`, `index.html`, `tsconfig.json`, `package.json`.

**Acceptance**: `pnpm --filter @ribosome/web build` produces dist/.

### Task 10.6: tui client

1. Add `tui/src/components.tsx` — 13 @opentui/solid terminal components + ComponentMap.
2. Add `tui/src/app.tsx` — terminal demo app with bordered status bar.
3. Add `tui/src/index.tsx` — entry, reads session_id from argv.
4. Add `bunfig.toml` with `@opentui/solid/preload` for JSX transform.
5. Add `tsconfig.json`, `package.json`.

**Acceptance**: `bun --preload @opentui/solid/preload src/index.tsx rs-1` launches.

### Task 10.7: CI and docs

1. Add `frontends` CI job (pnpm install, typecheck, test, web build).
2. Update README.md with frontend section, architecture diagram, package table.
3. Update architecture.md with frontend architecture, renderer factory, reconcile.

**Acceptance**: CI runs frontend job alongside existing OCaml jobs.

### Task 10.8: demo.sh

1. Add `demo.sh` with standalone and `SKIP_SERVER=1` modes.
2. Sets `RIBOSOME_DEBUG=1`, logs to `.logs/`, cleanup trap.
3. Prints web URL and TUI run command.

**Acceptance**: `./demo.sh` starts server + web; `SKIP_SERVER=1 ./demo.sh` starts web only.

---

## Feature 11: UI-Initiated Generation

The UI always initiates. The first screen is deterministic (input + submit), not agent-generated. Agent connection is lazy — fires only when the user submits a prompt.

The home screen is a regular template with a submittable. The user types, clicks submit, and that produces a normal `component_event` (submit) → `user_turn`. There is no special "request_generation" message. The server-side logic (lazy harness connection, triggering agent generation) handles the first turn the same as any subsequent turn — the only difference is the harness isn't connected yet.

### Architecture

```
UI Client                     Server                      Harness Adapter
   │                           │                              │
   │── attach ────────────────►│ creates session              │
   │◄─ session_state ─────────┤ (with home template tree)     │
   │                           │                              │
   │  user types subject       │                              │
   │  user clicks submit       │                              │
   │── component_event ───────►│ produces UserTurn            │
   │                           │── user_turn ────────────────►│ (first turn: triggers
   │                           │                              │  promptAsync + attach)
   │                           │◄─ attach ────────────────────┤
   │                           │◄─ delta ─────────────────────┤ agent streams JSON
   │◄─ template_update ───────┤                               │
   │◄─ template_update ───────┤                               │
   │  user interacts           │                              │
   │── component_event ───────►│── user_turn ────────────────►│ inject into agent
   │                           │◄─ delta ─────────────────────┤ next generation
   │◄─ template_update ───────┤                               │
```

### Phase 1 — Step A: Home template, /templates endpoint

#### Task 11.1: Home template builder ✅

1. Add `ribosome-server/src/home_template.ml`/`.mli`.
2. Define `home_json : string` — a template JSON string with a container, title text, subtitle, and a submittable with a text input and submit button.
3. Define `templates_json : string` — a template JSON string with all 13 component kinds in a vertical container (storybook).
4. Both are decoded via `Ribosome.Template.decode_string` to validate at load time.
5. Export `home_tree : Ribosome.Template.t` and `templates_tree : Ribosome.Template.t`.

**Acceptance**: both JSON strings decode and validate without errors.

#### Task 11.2: Seed home template on session creation ✅

1. In `ui_runtime.ml`, `register_session` sets `tree = Some Home_template.home_tree` and `revision = 1` directly (no Telomere/generation pipeline — JSON is validated at load).
2. `handle_attach` broadcasts `session_state` with the home tree.
3. Reconnect (attach with existing session) skips seeding.

**Acceptance**: UI client receives session_state with a non-empty tree on first attach.

#### Task 11.3: Add /templates endpoint (debug mode only) ✅

1. In `main.ml`, add a `Dream.get "/templates"` route.
2. Returns `templates_json` when `Debug.enabled` is true.
3. Returns 404 when debug is disabled.

**Acceptance**: `curl localhost:8787/templates` returns JSON in debug mode, 404 otherwise.

#### Task 11.4: Web app /templates route

1. Add a client-side `/templates` route to the web app.
2. Fetches JSON from `:8787/templates` (server) and renders it with the existing Solid components.
3. Shows all 13 component kinds vertically.

**Acceptance**: navigating to `/templates` in the web app renders the storybook.

### Phase 1 — Step B: Harness bidirectional, adapter, live conversation

#### Task 11.5: Extend Message_queue for harness outbound

1. Add a second hashtable to `message_queue.ml` for harness-bound messages.
2. Add `push_harness session_id msg` and `drain_harness session_id`.
3. Update `.mli`.

**Acceptance**: harness queue operates independently from UI queue.

#### Task 11.6: Harness handler — drain outbound queue

1. In `harness_handler.ml`, add drain-before-receive using `Lwt.pick` with a 1s timeout (adapter won't send messages until it receives a user_turn).
2. Drain `Message_queue.drain_harness` and send to WebSocket.
3. Also wire `send_user_turn` in `main.ml` to `Message_queue.push_harness` (fixes the existing no-op stub).

**Acceptance**: messages pushed to harness queue are delivered to the adapter WebSocket.

#### Task 11.7: Adapter — proactive connect and late attach

1. In `adapters/opencode/src/plugin.ts`, connect harness WS on plugin load (not waiting for start tool).
2. On receiving `user_turn` from harness WS: send `attach` with session_id and `"pending"` nonce, then call `promptAsync` with the user turn content.
3. Keep existing start-tool flow as fallback.

**Acceptance**: UI submit triggers agent generation without agent calling start tool first.

#### Task 11.8: End-to-end demo

1. Update `demo.sh` messaging for the new flow.
2. Start server + web → UI shows home screen → type subject → submit → agent generates → UI renders.
3. Test with `SKIP_SERVER=1` for OpenCode integration.

**Acceptance**: full conversation flow works end-to-end from UI submit to agent response.

### Phase 2 — Session listing (future)

#### Task 11.9: Harness protocol — session list

1. Add `SessionList` message (adapter→server): `{ sessions : [{ id : string; title : string; status : string }] }`.
2. Adapter proactively sends on connect and whenever sessions change.

#### Task 11.10: Server — cache session list, build home template dynamically

1. `Harness_runtime` stores latest `SessionList`.
2. Home template builder includes session buttons from cached list.
3. `user_turn` from a session button resumes an existing conversation.

**Acceptance**: home screen shows resumable conversations from the provider.
