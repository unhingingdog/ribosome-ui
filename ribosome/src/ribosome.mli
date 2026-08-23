(** Ribosome: typed template ADT, codec, validation, reconciliation, and session
    state for generative UI.

    Ribosome owns a closed OCaml template ADT plus JSON codecs, invariant
    validation, stable-ID reconciliation, session state, and mode/skill bundles.
    It has no dependency on MCP, Dream, WebSockets, or any harness.

    Codec helpers (Codec_decode, Codec_encode, Codec_error) are implementation
    details kept out of the public API. Template.Decode, Template.Encode, and
    Template.Codec_error provide the supported public aliases. *)

(** {2 Core template ADT} *)

module Template : module type of Template

(** {2 Template validation} *)

module Validate : module type of Template_validate

(** {2 Template reconciliation} *)

module Reconcile : module type of Template_reconcile

(** {2 Semantic events} *)

module Event : module type of Template_event

(** {2 Incremental parser} *)

module Incremental : module type of Incremental

(** {2 Mode and skill bundles} *)

module Mode : module type of Mode
module Mode_registry : module type of Mode_registry

(** {2 Session state} *)

module Session : module type of Session

val version : string
(** Release version for protocol negotiation. *)
