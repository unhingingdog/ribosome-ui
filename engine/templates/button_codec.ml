open Melange_json.Primitives

let deserialise_action json =
  match Js.Json.decodeString json with
  | Some "Submit" -> Button.Submit
  | Some action when String.length action > 0 ->
    if String.length action >= 9 && String.sub action 0 9 = "Navigate:" then
      Button.Navigate (String.sub action 9 (String.length action - 9))
    else Button.Custom action
  | _ -> failwith "expected action string"

let deserialise json =
  let open Melange_json.Of_json in
  {
    Button.kind = field "kind" string json;
    id = field "id" string json;
    label = field "label" string json;
    action = field "action" deserialise_action json;
    disabled = Helpers.optional_field "disabled" bool json;
  }

let serialise button clicked =
  let clicked = match clicked with Some value -> value | None -> false in
  Js.Json.object_ (Js.Dict.fromList [
    ("kind", string_to_json button.Button.kind);
    ("id", string_to_json button.id);
    ("label", string_to_json button.label);
    ("clicked", bool_to_json clicked);
  ])
