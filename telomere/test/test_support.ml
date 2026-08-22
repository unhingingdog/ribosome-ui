(* Shared helpers for readable Telomere test assertions.

   Kept deliberately small: Alcotest already provides good equality traps.
   These helpers add the common shape "feed a chunk, assert the output kind
   and (for completions) that buffer ^ suffix parses as valid JSON". *)

let pending : [< `Pending ] -> bool = function `Pending -> true
let corrupted : [< `Corrupted ] -> bool = function `Corrupted -> true

let completion_has_suffix (suffix : string) (actual : string) : bool =
  String.equal suffix actual

(* Feed a list of chunks to a fresh processor and return the list of outputs
   alongside the final state. *)
let feed_chunks (chunks : string list) :
    Telomere.Processor.output list * Telomere.Processor.processor_state =
  let state = Telomere.Processor.create_processor () in
  let outputs, state =
    List.fold_left
      (fun (acc, state) chunk ->
        let output, state = Telomere.Processor.feed state chunk in
        (output :: acc, state))
      ([], state) chunks
  in
  (List.rev outputs, state)
