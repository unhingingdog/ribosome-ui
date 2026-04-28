# Telomere

Telomere is a partial JSON parser and balancer. It is designed to make JSON syntactically valid by providing the suffix string required to close it off (the "telomere"). Its main purpose is to close off streaming structured data from an LLM, so that a UI can be rendered incrementally like a plain text chat.

This is a port from a Rust project: [telomere-json](https://crates.io/crates/telomere-json). It is almost a 1-to-1 port, given the similarity of the languages. For that reason it is mostly AI generated, and relatively lightly tested, relying on substantial logical coverage in the Rust repo.

## Usage

The public API is in `Balancer.ml`. State is a plain immutable record - thread it forward on each chunk.

```ocaml
open Balancer

(* Create a fresh balancer state *)
let state = create ()

(* Feed a chunk of (possibly partial) JSON.
   Returns Ok (completion, new_state) or Error (error, new_state). *)
let result = process_delta state "{\"name\":\"Alice\",\"age\""

match result with
| Ok (completion, _state) ->
  (* completion = ":42}" — the chars needed to make it valid JSON *)
  Printf.printf "Append: %s\n" completion
| Error (NotClosable, _state) ->
  (* The stream is mid-token (e.g. after a colon, or inside a string).
     Not an error — keep feeding chunks. *)
  ()
| Error (_, poisoned_state) ->
  (* Hard error — the JSON is structurally corrupt.
     poisoned_state.is_corrupted = true; all future calls will fast-path here. *)
  ()
```

### Streaming across multiple chunks

```ocaml
let chunks = ["{\"name\":\"Al"; "ice\",\"sc"; "ore\":42"]

let final_result =
  List.fold_left (fun acc chunk ->
    let state = match acc with
      | Ok (_, s)    -> s
      | Error (_, s) -> s
    in
    process_delta state chunk
  ) (Ok ("", create ())) chunks

(* final_result = Ok ("}", state) *)
(* Appending "}" produces valid JSON: {"name":"Alice","score":42} *)
```

### Error semantics

| Result                                        | Meaning                                                                                   | `is_corrupted` | Action                                           |
| --------------------------------------------- | ----------------------------------------------------------------------------------------- | -------------- | ------------------------------------------------ |
| `Ok (completion, state)`                      | Chunk processed. `completion` closes the JSON.                                            | `false`        | Append completion to render.                     |
| `Error (NotClosable, state)`                  | Mid-token (after `:`, inside a string, partial literal). Stream is still valid.           | `false`        | Discard completion for this chunk; keep feeding. |
| `Error (_, state)` where `state.is_corrupted` | Structural error (mismatched brackets, invalid character). Stream is permanently invalid. | `true`         | Stop processing.                                 |
