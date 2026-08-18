open Melange_json.Primitives

let deserialise json =
  let open Melange_json.Of_json in
  {
    List.kind = field "kind" string json;
    id = field "id" string json;
    ordered = Helpers.optional_field "ordered" bool json;
    children = [];
  }

let serialise list child_serialiser =
  let base = [
    ("kind", string_to_json list.List.kind);
    ("id", string_to_json list.id);
    ("children", list_to_json child_serialiser list.children);
  ] in
  let fields = match list.ordered with
    | Some ordered -> base @ [("ordered", bool_to_json ordered)]
    | None -> base
  in
  Js.Json.object_ (Js.Dict.fromList fields)
