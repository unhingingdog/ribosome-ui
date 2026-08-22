(* Ribosome core package entry point.

   The full typed template ADT, codecs, validation, reconciliation, session
   state, and mode registry are added in later tasks. This placeholder makes
   the native library buildable and proves the dependency on [telomere] links
   correctly across the two packages. *)

module Template = Template
module Validate = Template_validate

let processor = Telomere.Processor.create_processor
let version = "0.0.0"
