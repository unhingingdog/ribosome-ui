open Telomere
open Parser
open Types
open Utils.Log

let initial_processor_state = Processor.create_processor ()

type template_health =
  | Healthy
  | SoftBroken of string
  | HardBroken of string

let combine_health a b =
  match a, b with
  | HardBroken _ as hard, _ | _, (HardBroken _ as hard) -> hard
  | SoftBroken _ as soft, _ | _, (SoftBroken _ as soft) -> soft
  | Healthy, Healthy -> Healthy

let rec children_health health = function
  | [] -> health
  | child :: rest ->
    children_health (combine_health health (template_health child)) rest

and template_health = function
  | Broken (Hard message) -> HardBroken message
  | Broken (Soft message) -> SoftBroken message
  | Container container ->
      children_health Healthy container.children
  | List list ->
      children_health Healthy list.children
  | Submittable _ | Image _ | Text _ | Badge _ | Stat _ | Divider _ -> Healthy

module Telomere_result = struct
  type t =
    | Pending of Processor.processor_state 
    | Parsed of (template * Processor.processor_state)
    | Failed of (string * Processor.processor_state)
end

let handle_chunk chunk processor = 
  debug "[ribosome backend] chunk received" chunk;
  let (telomere_result, processor_state) = Processor.feed  processor chunk in
  match telomere_result with 
    | Pending ->
        debug "[ribosome backend] pending buffer" processor_state.buffer;
        Telomere_result.Pending (processor_state)
    | Completion telomere -> 
        let payload = processor_state.buffer ^ telomere in
        debug "[ribosome backend] complete JSON candidate" payload;
        (match parse_data payload with 
        | Ok template ->
            (match template_health template with
            | Healthy ->
                debug1 "[ribosome backend] parsed complete template";
                Telomere_result.Parsed (template, processor_state)
            | SoftBroken message ->
                debug "[ribosome backend] soft parse failure; waiting for more bytes" message;
                Telomere_result.Pending processor_state
            | HardBroken message ->
                debug "[ribosome backend] hard parse failure" message;
                Telomere_result.Failed (message, processor_state))
        | Error e ->
            debug "[ribosome backend] parse_data error" e;
            Telomere_result.Failed (e, processor_state))
    | Corrupted ->
        debug "[ribosome backend] hard telomere error buffer" processor_state.buffer;
        Telomere_result.Failed ("Hard telomere error", processor_state)
