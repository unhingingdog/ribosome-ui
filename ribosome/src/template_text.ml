type text_type = Paragraph | H1 | H2 | H3 | H4 | H5 | H6

let text_type_of_string = function
  | "Paragraph" -> Paragraph
  | "H1" -> H1
  | "H2" -> H2
  | "H3" -> H3
  | "H4" -> H4
  | "H5" -> H5
  | "H6" -> H6
  | s -> failwith ("unknown text_type: " ^ s)

let string_of_text_type = function
  | Paragraph -> "Paragraph"
  | H1 -> "H1"
  | H2 -> "H2"
  | H3 -> "H3"
  | H4 -> "H4"
  | H5 -> "H5"
  | H6 -> "H6"

type t = { id : string; text_type : text_type; value : string }
