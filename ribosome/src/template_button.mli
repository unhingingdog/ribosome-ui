type action = Submit | Navigate of string | Custom of string
type t = { id : string; label : string; action : action; disabled : bool }

val action_of_string : string -> action
val string_of_action : action -> string
val definition : Template_definition.t
val decode : Yojson.Safe.t -> (t, Codec_error.t) result
val encode : t -> Yojson.Safe.t
