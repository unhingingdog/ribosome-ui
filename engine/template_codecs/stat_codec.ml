open Melange_json.Primitives

let deserialise json =
  let open Melange_json.Of_json in
  {
    Stat.kind = field "kind" string json;
    id = field "id" string json;
    label = field "label" string json;
    value = field "value" string json;
    secondary = Helpers.optional_field "secondary" string json;
  }

let serialise stat =
  let base = [
    ("kind", string_to_json stat.Stat.kind);
    ("id", string_to_json stat.id);
    ("label", string_to_json stat.label);
    ("value", string_to_json stat.value);
  ] in
  let fields = match stat.secondary with
    | Some secondary -> base @ [("secondary", string_to_json secondary)]
    | None -> base
  in
  Js.Json.object_ (Js.Dict.fromList fields)
