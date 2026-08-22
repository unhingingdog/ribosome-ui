type path_segment = Field of string | Index of int
type field_path = path_segment list
type category = MissingField | WrongType | InvalidValue | UnknownEnum
type t = { path : field_path; category : category; message : string }

val category_to_string : category -> string
val format_path : field_path -> string
val make : field_path -> category -> string -> t
val to_string : t -> string
val with_path : path_segment -> t -> t
