type text_type = Paragraph | H1 | H2 | H3 | H4 | H5 | H6
type t = { id : string; text_type : text_type; value : string }

val text_type_of_string : string -> text_type
val string_of_text_type : text_type -> string
val definition : Template_definition.t
val decode : Yojson.Safe.t -> (t, Codec_error.t) result
val encode : t -> Yojson.Safe.t
