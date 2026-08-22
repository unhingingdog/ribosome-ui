type option_ = { value : string; label : string }

type t = {
  id : string;
  label : string;
  options : option_ list;
  selected : string option;
}

val definition : Template_definition.t
