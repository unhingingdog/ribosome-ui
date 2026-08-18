open Melange_json.Primitives

let deserialise_option json =
  let open Melange_json.Of_json in
  {
    Select.value = field "value" string json;
    label = field "label" string json;
  }

let serialise_option option_ =
  Js.Json.object_ (Js.Dict.fromList [
    ("value", string_to_json option_.Select.value);
    ("label", string_to_json option_.label);
  ])

let options_of_array array =
  let rec loop index options =
    if index < 0 then options
    else loop (index - 1) (deserialise_option array.(index) :: options)
  in
  loop (Array.length array - 1) []

let deserialise json =
  let open Melange_json.Of_json in
  {
    Select.kind = field "kind" string json;
    id = field "id" string json;
    label = field "label" string json;
    options = field "options" (fun value ->
      match Js.Json.decodeArray value with
      | Some array -> options_of_array array
      | None -> failwith "expected options array"
    ) json;
    selected = Helpers.optional_field "selected" string json;
  }

let serialise select selected =
  let base = [
    ("kind", string_to_json select.Select.kind);
    ("id", string_to_json select.id);
    ("label", string_to_json select.label);
    ("options", list_to_json serialise_option select.options);
  ] in
  let fields = match selected with
    | Some value -> base @ [("selected", string_to_json value)]
    | None -> base
  in
  Js.Json.object_ (Js.Dict.fromList fields)
