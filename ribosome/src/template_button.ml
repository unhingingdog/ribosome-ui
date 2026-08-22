type action = Submit | Navigate of string | Custom of string

let action_of_string = function
  | "Submit" -> Submit
  | s when String.length s >= 10 && String.sub s 0 10 = "Navigate:" ->
      Navigate (String.sub s 10 (String.length s - 10))
  | s -> Custom s

let string_of_action = function
  | Submit -> "Submit"
  | Navigate dest -> "Navigate:" ^ dest
  | Custom s -> s

type t = { id : string; label : string; action : action; disabled : bool }
