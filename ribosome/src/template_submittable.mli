val definition : Template_definition.t

type field = FieldInput of Template_input.t | FieldSelect of Template_select.t
type t = { id : string; value : field list; button : Template_button.t option }

val decode : Yojson.Safe.t -> (t, Codec_error.t) result
val encode : t -> Yojson.Safe.t
