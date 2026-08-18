open Melange_json.Primitives

let deserialise json =
  let open Melange_json.Of_json in
  {
    Container.kind = field "kind" string json;
    id = field "id" string json;
    direction = field "direction" (fun value -> Container.direction_of_string (string value)) json;
    children = [];
  }

let serialise template child_serialiser =
  let serialised_children = list_to_json child_serialiser template.Container.children in
  Js.Json.object_ (Js.Dict.fromList [
    ("kind", string_to_json template.kind);
    ("id", string_to_json template.id);
    ("direction", string_to_json (Container.string_of_direction template.direction));
    ("children", serialised_children);
  ])
