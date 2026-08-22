(** Telomere: incremental JSON completion for streamed LLM output.

    Telomere receives streamed text and answers whether it can be closed into
    valid JSON now, returning the suffix required to close it. It is the
    mandatory incremental parsing layer in the Ribosome streaming pipeline.

    See {{:https://crates.io/crates/telomere-json} the original Rust project}.
*)

module Processor : sig
  type processor_state
  type output = Pending | Completion of string | Corrupted

  val create_processor : unit -> processor_state
  val feed : processor_state -> string -> output * processor_state
end
