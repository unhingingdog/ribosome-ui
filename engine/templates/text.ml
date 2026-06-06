open Melange_json.Primitives

let optional_field name decoder json =
  match Js.Json.decodeObject json with
  | None -> None
  | Some obj ->
    match Js.Dict.get obj name with
    | None -> None
    | Some value -> Some (decoder value)

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

let text_type_of_json json =
  match Js.Json.decodeString json with
  | Some value -> text_type_of_string value
  | None ->
    match Js.Json.decodeArray json with
    | Some arr when Array.length arr = 1 ->
      text_type_of_string (string_of_json arr.(0))
    | _ -> failwith "expected text_type string"

let text_type_to_json value = string_to_json (string_of_text_type value)

type t = {
  kind: string;
  id: string;
  text_type: text_type;
  content: string
}

let of_json json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    text_type = field "text_type" text_type_of_json json;
    content =
      match optional_field "value" string json with
      | Some value -> value
      | None -> field "content" string json;
  }

let to_json text =
  Js.Json.object_ (Js.Dict.fromArray [|
    ("kind", string_to_json text.kind);
    ("id", string_to_json text.id);
    ("text_type", text_type_to_json text.text_type);
    ("value", string_to_json text.content);
  |])
