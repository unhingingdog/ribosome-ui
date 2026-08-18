open Melange_json.Primitives

let deserialise_variant json =
  match Js.Json.decodeString json with
  | Some value -> Badge.badge_variant_of_string value
  | None -> failwith "expected badge variant string"

let deserialise json =
  let open Melange_json.Of_json in
  {
    Badge.kind = field "kind" string json;
    id = field "id" string json;
    label = field "label" string json;
    variant = field "variant" deserialise_variant json;
  }

let serialise badge =
  Js.Json.object_ (Js.Dict.fromList [
    ("kind", string_to_json badge.Badge.kind);
    ("id", string_to_json badge.id);
    ("label", string_to_json badge.label);
    ("variant", string_to_json (Badge.string_of_badge_variant badge.variant));
  ])
