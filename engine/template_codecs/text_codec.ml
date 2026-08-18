open Melange_json.Primitives

let deserialise_text_type json =
  match Js.Json.decodeString json with
  | Some value -> Text.text_type_of_string value
  | None ->
    match Js.Json.decodeArray json with
    | Some arr when Array.length arr = 1 ->
      Text.text_type_of_string (string_of_json arr.(0))
    | _ -> failwith "expected text_type string"

let serialise_text_type value =
  string_to_json (Text.string_of_text_type value)

let deserialise json =
  let open Melange_json.Of_json in
  {
    Text.kind = field "kind" string json;
    id = field "id" string json;
    text_type = field "text_type" deserialise_text_type json;
    content =
      match Helpers.optional_field "value" string json with
      | Some value -> value
      | None -> field "content" string json;
  }

let serialise text =
  Js.Json.object_ (Js.Dict.fromList [
    ("kind", string_to_json text.Text.kind);
    ("id", string_to_json text.id);
    ("text_type", serialise_text_type text.text_type);
    ("value", string_to_json text.content);
  ])
