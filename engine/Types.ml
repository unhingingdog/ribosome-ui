open Melange_json.Primitives

let optional_field name decoder json =
  match Js.Json.decodeObject json with
  | None -> None
  | Some obj ->
    match Js.Dict.get obj name with
    | None -> None
    | Some value -> Some (decoder value)

type input_value = Int of int | String of string

let input_value_of_json json =
  match Js.Json.decodeString json with
  | Some value -> String value
  | None ->
    match (try Some (int_of_json json) with _ -> None) with
    | Some value -> Int value
    | None ->
      match Js.Json.decodeObject json with
      | Some obj ->
        (match Js.Dict.get obj "String", Js.Dict.get obj "Int" with
        | Some value, _ -> String (string_of_json value)
        | None, Some value -> Int (int_of_json value)
        | None, None -> failwith "expected input value string, number, { String }, or { Int }")
      | None ->
        match Js.Json.decodeArray json with
        | Some arr when Array.length arr = 2 ->
          (match Js.Json.decodeString arr.(0) with
          | Some "String" -> String (string_of_json arr.(1))
          | Some "Int" -> Int (int_of_json arr.(1))
          | _ -> failwith "expected input value tag String or Int")
        | _ -> failwith "expected input value string or number"

let input_value_to_json = function
  | Int value -> int_to_json value
  | String value -> string_to_json value

type input = {
  kind: string;
  id: string;
  value: input_value 
} [@@deriving json]

type submittable = {
  kind: string;
  id: string;
  value: input list;
} [@@deriving json]

type image = {
  kind: string;
  id: string;
  src: string;
  alt: string;
} [@@deriving json]

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

type text = {
  kind: string;
  id: string;
  text_type: text_type;
  content: string
}

let text_of_json json =
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

let text_to_json text =
  Js.Json.object_ (Js.Dict.fromArray [|
    ("kind", string_to_json text.kind);
    ("id", string_to_json text.id);
    ("text_type", text_type_to_json text.text_type);
    ("value", string_to_json text.content);
  |])

type broken =
  | Soft  of string
  | Hard of string [@@deriving json]

type container = {
  kind: string;
  id: string;
  children: template list 
} and template = 
  | Input of input
  | Submittable of submittable
  | Image of image
  | Text of text 
  | Container of container 
  | Broken of broken

let container_of_json json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    children = []
  }
