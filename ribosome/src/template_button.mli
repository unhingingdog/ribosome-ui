type action = Submit | Navigate of string | Custom of string

val action_of_string : string -> action
val string_of_action : action -> string
val definition : Template_definition.t

type t = { id : string; label : string; action : action; disabled : bool }
