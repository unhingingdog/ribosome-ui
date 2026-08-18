type text_type = Paragraph | H1 | H2 | H3 | H4 | H5 | H6

let text_type_of_string = function
  | "Paragraph" -> Paragraph
  | "H1" -> H1
  | "H2" -> H2
  | "H3" -> H3
  | "H4" -> H4
  | "H5" -> H5
  | "H6" -> H6
  | value -> failwith ("unknown text_type: " ^ value)

let string_of_text_type = function
  | Paragraph -> "Paragraph"
  | H1 -> "H1"
  | H2 -> "H2"
  | H3 -> "H3"
  | H4 -> "H4"
  | H5 -> "H5"
  | H6 -> "H6"

type t = {
  kind: string;
  id: string;
  text_type: text_type;
  content: string
}

let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "text";
    intent = "Display textual content to the user.";
    instructions = "Use text for headings, paragraphs, labels, explanations, and short feedback.";
    fields = [
      kind_field "text";
      id_field "text node";
      string_field "text_type" "One of: Paragraph | H1 | H2 | H3 | H4 | H5 | H6.";
      string_field "value" "Text content to render.";
    ];
  }
