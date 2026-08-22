(* Ribosome core package entry point.

   The full typed template ADT, codecs, validation, reconciliation, session
   state, and mode registry are added in later tasks. This placeholder makes
   the native library buildable and proves the dependency on [telomere] links
   correctly across the two packages. *)

module Template = Template
module Validate = Template_validate
module Reconcile = Template_reconcile
module Event = Template_event
module Incremental = Incremental
module Mode = Mode
module Session = Session

let processor = Telomere.Processor.create_processor
let version = "0.0.0"
