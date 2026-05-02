# Telomere

Telomere is a partial JSON parser and balancer. It is designed to make JSON syntactically valid by providing the suffix string required to close it off (the "telomere"). Its main purpose is to close off streaming structured data from an LLM, so that a UI can be rendered incrementally like a plain text chat.

This is a port from a Rust project: [telomere-json](https://crates.io/crates/telomere-json). It is almost a 1-to-1 port, given the similarity of the languages. For that reason it is mostly AI generated, and relatively lightly tested, relying on substantial logical coverage in the Rust repo.

## Usage

The top-level streaming API is in `Processor.ml`. State is a plain immutable record - thread it forward on each chunk. The processor keeps the low-level balancer state plus the accumulated input buffer.

```ocaml
open Processor

(* Create a fresh processor state *)
let state = create_processor ()

(* Feed a chunk of (possibly partial) JSON.
   Returns (output, new_state). *)
let (output, state) = feed state "{\"name\":\"Alice\",\"age\""

match output with
| Completion completion ->
  (* completion = ":42}" — the chars needed to make it valid JSON *)
  Printf.printf "Append: %s\n" completion
| Pending ->
  (* The stream is mid-token (e.g. after a colon, or inside a string).
     Not an error — keep feeding chunks. *)
  ()
| Corrupted ->
  (* Hard error — the JSON is structurally corrupt.
     The internal balancer is poisoned; all future calls will fast-path here. *)
  ()
```

### Streaming across multiple chunks

```ocaml
let chunks = ["{\"name\":\"Al"; "ice\",\"sc"; "ore\":42"]

let (final_output, final_state) =
  List.fold_left (fun (_, state) chunk ->
    feed state chunk
  ) (Pending, create_processor ()) chunks

(* final_output = Completion "}" *)
(* Appending "}" produces valid JSON: {"name":"Alice","score":42} *)
```

The generated JavaScript exports use Melange's OCaml names:

```js
import { create_processor, feed } from "./dist/telomere/Processor.js";

let state = create_processor();
let [output, nextState] = feed(state, '{"name":"Alice"');
```

In the compiled JavaScript representation, `Pending` is the plain number `0`, `Corrupted` is the plain number `1`, and `Completion value` is an object like `{ TAG: 0, _0: value }`.

## Lower-level balancer

`Balancer.ml` is the lower-level API used by `Processor.ml`. Use it directly when you want completion/error details without the accumulated buffer wrapper.

```ocaml
open Balancer

let state = create ()
let result = process_delta state "{\"name\":\"Alice\",\"age\""

match result with
| Ok (completion, _state) ->
  Printf.printf "Append: %s\n" completion
| Error (NotClosable, _state) ->
  ()
| Error (_, poisoned_state) ->
  (* poisoned_state.is_corrupted = true *)
  ()
```

### Error semantics

| Processor output       | Balancer result                                | Meaning                                                                                   | Action                                           |
| ---------------------- | ---------------------------------------------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------ |
| `Completion completion` | `Ok (completion, state)`                       | Chunk processed. `completion` closes the JSON.                                            | Append completion to render.                     |
| `Pending`              | `Error (NotClosable, state)`                   | Mid-token (after `:`, inside a string, partial literal). Stream is still valid.           | Discard completion for this chunk; keep feeding. |
| `Corrupted`            | `Error (_, state)` where `state.is_corrupted`  | Structural error (mismatched brackets, invalid character). Stream is permanently invalid. | Stop processing.                                 |
