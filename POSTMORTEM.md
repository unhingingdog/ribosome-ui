# Ribosome UI Wiring: Post-Mortem

## What we built

A headless opencode adapter that connects the Ribosome generative UI runtime to an opencode serve instance. The user interacts via a web UI (Vite/React) that connects to the ribosome-server over WebSocket. The server forwards user submissions to the opencode adapter plugin, which injects them as prompts into an opencode session. The model's streaming text output is forwarded back to the server as deltas, which are incrementally decoded and reconciled into the live UI tree.

## What went right

- **Core OCaml runtime is sound.** The telomere JSON balancer, incremental decoder, template codec, and reconciler all work correctly. The ratatui port demonstrated real-time shape-by-shape diagram rendering.
- **Simple conversation worked.** Plain text container responses with a submittable form rendered correctly and supported multiple turns.
- **Simple diagrams worked.** A box, an isometric cube, an isometric apartment building, and a smiley face all rendered shape-by-shape in real time via streaming reconcile.
- **Prompt engineering for id-matching worked.** After telling the model to reuse an existing template id from the `[ribosome-tree]`, the model consistently used `id:"home-root"` and reconciles succeeded.
- **Skills content is correct.** The ported ribosome skill (adapted from the ratatui-port branch) and the isometric-diagram skill (with integer grid math, correct tones, correct primitive fields) are accurate against the codec.
- **Model output quality was good.** When the model's output reached the server intact, the JSON was valid, schema-compliant, and semantically appropriate. The 6,481-byte isometric chip factory diagram (50+ primitives) was correct JSON.
- **Two-turn integration test passes.** The OCaml `ribosome-vslice-two-turn` test confirms the server-side session lifecycle works end-to-end.

## What went wrong

### 1. Reconciliation ID mismatch (first session)

**Symptom:** 453 rejections (402 decode failures + 51 reconcile failures), zero accepted templates.

**Cause:** The model generated templates with `id:"drone-root"` but the existing tree had `id:"home-root"`. The reconciler (`template_reconcile.ml`) searches for the target id in the tree and rejects if not found. The AGENTS.md and SKILL_INSTRUCTIONS didn't explain that the id must match an existing template.

**Fix:** Updated AGENTS.md rule 6 and SKILL_INSTRUCTIONS to explain: "your template's id must match the id of an existing template in the [ribosome-tree]."

### 2. Schema compliance failures (first session)

**Symptom:** 402 decode rejections with errors like `kind: unknown enum value`, `direction: missing field`, `text_type: unknown enum value`, `children: missing field`.

**Cause:** The condensed SKILL_INSTRUCTIONS only listed kind names without full field specs. The model didn't know the exact enum values or required fields.

**Fix:** Replaced the ribosome SKILL.md with the full schema from the ratatui-port branch, adapted to the current codec (capitalized enums, object size, correct primitive field names, correct tones).

### 3. Model hung on reasoning (glm-5.2)

**Symptom:** Model stuck at 62% CPU for 4+ minutes, producing zero text output. Empty reasoning part in the opencode database.

**Cause:** The headless session didn't specify a model. Opencode defaulted to `glm-5.2`, which got stuck in a reasoning loop. The previous session used `deepseek-v4-pro`, which worked.

**No fix applied.** The model selection is controlled by opencode's default, not the adapter.

### 4. User prompt text corrupting the stream (message.part.updated)

**Symptom:** Telomere balancer corrupted on delta seq=1 and rejected all 13,000+ subsequent deltas. The model's valid 6,481-byte output was never processed.

**Cause:** Opencode fired `message.part.updated` events for the user's prompt text (the 2,090-byte part containing SKILL_INSTRUCTIONS with its embedded JSON example `{"kind":"container","id":"root",...}`). The adapter processed these as model output, forwarding the `{` from the example, then hitting non-JSON text ("Rules:") which corrupted the balancer permanently.

**Fix:** Only process `message.part.delta` events (streaming model output), not `message.part.updated` (which fires for user-injected parts too).

### 5. generation_completed never sent

**Symptom:** Model finished, session went idle, but the server never received `generation_completed`. The UI hung showing a partial template with no input.

**Cause:** After filtering out `message.part.updated`, the generation entry was only created when a `message.part.delta` event arrived. But `handleSessionIdle` couldn't find the generation entry because it was already deleted or not yet created.

**Fix:** Added `lastGenerationIds` map as fallback in `handleSessionIdle`. Also flush the batch buffer before sending completion.

### 6. WebSocket backpressure (silent data loss)

**Symptom:** Adapter forwarded 161 deltas, server received only 115. 46 deltas (including the `submittable` form) silently vanished. No disconnect, no error.

**Cause:** The adapter sent each 2-13 byte delta as its own WebSocket frame. The Dream server couldn't read them fast enough, the TCP buffer filled, and frames were silently dropped. Node.js's `ws` library reports `bufferedAmount` as 0, so the backpressure check was ineffective.

**Fix:** Batch deltas into 16ms windows. Reduced data loss from 46 to 11 deltas, but didn't fully solve it.

### 7. Server-side generation idle timeout

**Symptom:** When `generation_completed` was lost, the server stayed stuck with an active generation forever.

**Fix:** Added a 15-second idle timer in `harness_handler.ml`. If no deltas arrive for 15 seconds, auto-complete the generation. This masks the symptom but the rendered template is still incomplete if deltas were lost.

### 8. sync_ui_to_harness overwriting generation state

**Symptom:** Second turn's deltas all rejected with "wrong generation" — every delta called `start_generation` which failed because an old generation was still active.

**Cause:** After `complete_generation` set `generation = None` in the harness session, UI change events (user typing) triggered `sync_ui_to_harness`, which copied the UI session (with the stale `generation = Some old_gen`) back to the harness, re-activating the completed generation.

**Fix:** `sync_ui_to_harness` now preserves the harness session's `generation` and `incremental` fields instead of overwriting them with the UI session's stale values.

### 9. Model replacing the form with a diagram

**Symptom:** UI showed content but no input field. The `<form>` element was empty.

**Cause:** The model used `id:"home-form"` for its diagram template. The reconciler replaced the submittable form with the diagram. No more input — conversation stalled.

**Fix:** Added rule to SKILL_INSTRUCTIONS: "Always include a submittable form with an input and a submit button. Never replace the form with a non-form template."

### 10. Skills not loaded by the headless adapter

**Symptom:** Model didn't know about the isometric-diagram skill or the full template schema. It guessed field names and enum values incorrectly.

**Cause:** The headless adapter bypasses the MCP `start` tool entirely. It creates an opencode session and injects prompts via `promptAsync`. The agent never calls `start`, so it never receives skill content. The MCP `start` tool (`mcp.ml`) loads skills from the mode registry and returns them, but this flow is only used in the interactive (non-headless) path.

**Attempted MCP approach:** Added MCP config to `opencode.json` so opencode starts the ribosome-server via MCP. Failed because MCP `local` type starts its own process — port conflict with the demo's separately-started server. Two separate processes can't share session state.

**Fix:** Added `/skills` HTTP endpoint to the ribosome-server. The adapter fetches skill content via HTTP on startup and prepends it to every injected prompt. No MCP dependency.

### 11. Adapter logging flooding the TUI

**Symptom:** Thousands of `[ribosome:info]` log lines appeared in the opencode TUI during normal (non-ribosome) sessions.

**Cause:** The adapter's verbose debug logging fired for every event on every session, not just ribosome sessions.

**Fix:** Gate logging to only fire for sessions in `activeSessionIds`.

### 12. Telomere balancer corruption (recurring, by design)

**Symptom:** Once the balancer corrupts, every subsequent delta returns `Corrupted` with no recovery. This recurred across multiple sessions whenever any invalid content entered the stream.

**Cause:** `balancer.ml:69` sets `is_corrupted = true` on any lexer error. `balancer.ml:95` fast-returns `Corrupted` for all subsequent feeds. This is correct by design — the balancer tracks JSON bracket/brace nesting character by character, and once it sees a mismatched close token, the stack is genuinely broken. There is no way to recover because there's no way to know what the correct nesting state should be. Recovery would mean guessing, which defeats the purpose of a balancer.

**Root cause is always the adapter.** Every corruption we observed was caused by invalid data entering the stream — user prompt text mixed in via `message.part.updated` events, or other adapter bugs. The balancer correctly rejected malformed JSON. The fix is always upstream: don't send bad data to the balancer.

## Architecture issues summary

The adapter is a thin TypeScript glue layer between opencode's event stream and the ribosome server's WebSocket. It has been the source of almost every failure:

1. **Event filtering** — distinguishing user prompt parts from model output parts
2. **Generation lifecycle** — ensuring `generation_completed` is always sent
3. **Transport reliability** — WebSocket backpressure causing silent data loss
4. **Session isolation** — ribosome sessions vs regular opencode sessions
5. **Skills delivery** — bypassing MCP means skills must be fetched separately

The core OCaml runtime (telomere, incremental decoder, reconciler, session management) is sound. The ratatui port proved this. The adapter just keeps mangling the stream.

## What still needs fixing

1. **Reliable delta delivery** — batching helped but didn't solve backpressure entirely; the last ~11 deltas per turn are still sometimes lost
2. **Skills in prompts** — the HTTP fetch works but increases prompt size significantly; may need lazy loading or skill selection
3. **Model selection** — the adapter should pin a model that works reliably with JSON generation
4. **End-to-end reliability** — simple conversation fails ~50% of the time due to the above issues combining
