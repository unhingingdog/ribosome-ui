open Melange_json.Primitives

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

let deserialise_text_type json =
  match Js.Json.decodeString json with
  | Some value -> text_type_of_string value
  | None ->
    match Js.Json.decodeArray json with
    | Some arr when Array.length arr = 1 ->
      text_type_of_string (string_of_json arr.(0))
    | _ -> failwith "expected text_type string"

let serialise_text_type value = string_to_json (string_of_text_type value)

type t = {
  kind: string;
  id: string;
  text_type: text_type;
  content: string
}

let deserialise json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    text_type = field "text_type" deserialise_text_type json;
    content =
      match Helpers.optional_field "value" string json with
      | Some value -> value
      | None -> field "content" string json;
  }

let serialise text =
  Js.Json.object_ (Js.Dict.fromList [
    ("kind", string_to_json text.kind);
    ("id", string_to_json text.id);
    ("text_type", serialise_text_type text.text_type);
    ("value", string_to_json text.content);
  ])

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
