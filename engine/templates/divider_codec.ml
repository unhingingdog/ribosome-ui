open Melange_json.Primitives

let deserialise json =
  let open Melange_json.Of_json in
  {
    Divider.kind = field "kind" string json;
    id = field "id" string json;
    label = Helpers.optional_field "label" string json;
  }

let serialise divider =
  let base = [
    ("kind", string_to_json divider.Divider.kind);
    ("id", string_to_json divider.id);
  ] in
  let fields = match divider.label with
    | Some label -> base @ [("label", string_to_json label)]
    | None -> base
  in
  Js.Json.object_ (Js.Dict.fromList fields)
