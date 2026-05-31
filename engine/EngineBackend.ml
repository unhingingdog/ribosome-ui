open Telomere
open Parser
open Types

let initial_processor_state = Processor.create_processor ()

module Telomere_result = struct
  type t =
    | Pending of Processor.processor_state 
    | Parsed of (template * Processor.processor_state)
    | Failed of (string * Processor.processor_state)
end

let handle_chunk chunk processor = 
  let (telomere_result, processor_state) = Processor.feed  processor chunk in
  match telomere_result with 
    | Pending -> Telomere_result.Pending (processor_state)
    | Completion telomere -> 
        (match parse_data (processor_state.buffer ^ telomere) with 
        | Ok template -> Telomere_result.Parsed (template, processor_state)
        | Error e -> Telomere_result.Failed (e, processor_state))
    | Corrupted -> Telomere_result.Failed ("Hard telomere error", processor_state)
