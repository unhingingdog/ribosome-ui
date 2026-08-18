open Melange_json.Primitives

let deserialise json =
  let open Melange_json.Of_json in
  {
    Image.kind = field "kind" string json;
    id = field "id" string json;
    src = field "src" string json;
    alt = field "alt" string json;
  }

let serialise image =
  Js.Json.object_ (Js.Dict.fromList [
    ("kind", string_to_json image.Image.kind);
    ("id", string_to_json image.id);
    ("src", string_to_json image.src);
    ("alt", string_to_json image.alt);
  ])
