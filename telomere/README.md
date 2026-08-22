# Telomere

Telomere is a partial JSON parser and balancer. It is designed to make JSON syntactically valid by providing the suffix string required to close it off (the "telomere"). Its main purpose is to close off streaming structured data from an LLM, so that a UI can be rendered incrementally like a plain text chat.

This is a port from a Rust project: [telomere-json](https://crates.io/crates/telomere-json). It is almost a 1-to-1 port, given the similarity of the languages.

## Usage

The top-level streaming API is in the `Telomere.Processor` module. State is a plain immutable abstract value — thread it forward on each chunk. The processor keeps the low-level balancer state plus the accumulated input buffer.

```ocaml
open Telomere.Processor

(* Create a fresh processor state *)
let state = create_processor ()

(* Feed a chunk of (possibly partial) JSON.
   Returns (output, new_state). *)
let output, state = feed state "{\"name\":\"Alice\",\"age\""

match output with
| Completion suffix ->
  (* suffix = ":42}" — the chars needed to make it valid JSON *)
  Printf.printf "Append: %s\n" suffix
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

let final_output, final_state =
  List.fold_left (fun (_, state) chunk ->
    feed state chunk
  ) (Pending, create_processor ()) chunks

(* final_output = Completion "}" *)
(* Appending "}" produces valid JSON: {"name":"Alice","score":42} *)
```

### Error semantics

| Processor output        | Meaning                                                                                   | Action                                           |
| ----------------------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------ |
| `Completion suffix`     | Chunk processed. `suffix` closes the JSON.                                                | Append suffix to render.                         |
| `Pending`               | Mid-token (after `:`, inside a string, partial literal). Stream is still valid.           | Discard completion for this chunk; keep feeding. |
| `Corrupted`             | Structural error (mismatched brackets, invalid character). Stream is permanently invalid. | Stop processing.                                 |
