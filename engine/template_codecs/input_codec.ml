open Melange_json.Primitives

let deserialise_value json =
  match Js.Json.decodeString json with
  | Some value -> Input.String value
  | None ->
    match (try Some (int_of_json json) with _ -> None) with
    | Some value -> Input.Int value
    | None -> failwith "expected input value string or number"

let serialise_value = function
  | Input.Int value -> int_to_json value
  | Input.String value -> string_to_json value

let deserialise json =
  let open Melange_json.Of_json in
  {
    Input.kind = field "kind" string json;
    id = field "id" string json;
    value = Helpers.optional_field "value" deserialise_value json;
  }

let serialise input =
  let base = [
    ("kind", string_to_json input.Input.kind);
    ("id", string_to_json input.id);
  ] in
  let fields = match input.value with
    | Some value -> base @ [("value", serialise_value value)]
    | None -> base
  in
  Js.Json.object_ (Js.Dict.fromList fields)
