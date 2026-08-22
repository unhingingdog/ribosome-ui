type text_type = Paragraph | H1 | H2 | H3 | H4 | H5 | H6

val text_type_of_string : string -> text_type
val string_of_text_type : text_type -> string

type t = { id : string; text_type : text_type; value : string }
