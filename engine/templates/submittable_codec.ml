open Melange_json.Primitives

let deserialise_field json =
  match Melange_json.Of_json.(field "kind" string json) with
  | "select" -> Submittable.FieldSelect (SelectCodec.deserialise json)
  | _ -> Submittable.FieldInput (InputCodec.deserialise json)

let serialise_field = function
  | Submittable.FieldInput input -> InputCodec.serialise input
  | Submittable.FieldSelect select -> SelectCodec.serialise select select.Select.selected

let deserialise json =
  let open Melange_json.Of_json in
  {
    Submittable.kind = field "kind" string json;
    id = field "id" string json;
    value = field "value" (list deserialise_field) json;
    button = Helpers.optional_field "button" ButtonCodec.deserialise json;
  }

let serialise submittable =
  let base = [
    ("kind", string_to_json submittable.Submittable.kind);
    ("id", string_to_json submittable.id);
    ("value", list_to_json serialise_field submittable.value);
  ] in
  let fields = match submittable.button with
    | Some button -> base @ [("button", ButtonCodec.serialise button None)]
    | None -> base
  in
  Js.Json.object_ (Js.Dict.fromList fields)
