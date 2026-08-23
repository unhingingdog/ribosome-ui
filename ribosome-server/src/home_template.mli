(** Deterministic templates served by the server before agent generation. *)

val home_tree : Ribosome.Template.t
(** The initial screen: a vertical container with a title, subtitle, and a
    submittable form (text input + submit button with [start:submit] action). *)

val home_json : string
(** JSON encoding of [home_tree]. *)

val templates_tree : Ribosome.Template.t
(** A storybook tree containing all 13 component kinds in a vertical container.
*)

val templates_json : string
(** JSON encoding of [templates_tree]. *)
