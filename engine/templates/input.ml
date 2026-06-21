open Melange_json.Primitives

type input_value = Int of int | String of string

let deserialise_input_value json =
  match Js.Json.decodeString json with
  | Some value -> String value
  | None ->
    match (try Some (int_of_json json) with _ -> None) with
    | Some value -> Int value
    | None -> failwith "expected input value string or number"

let serialise_input_value = function
  | Int value -> int_to_json value
  | String value -> string_to_json value

type t = {
  kind: string;
  id: string;
  value: input_value option
}

let deserialise json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    value = Helpers.optional_field "value" deserialise_input_value json;
  }

let serialise template = 
  let base = [
    ("kind", string_to_json template.kind);
    ("id", string_to_json template.id);
  ] in
  let fields = match template.value with
    | Some value -> base @ [("value", serialise_input_value value)]
    | None -> base
  in
  Js.Json.object_ (Js.Dict.fromList fields)

let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "input";
    intent = "Collect a user-editable value inside a submittable template.";
    instructions = "Only render input as part of a submittable template's value array.";
    fields = [
      kind_field "input";
      id_field "input";
      string_field "value" "Initial input value as a raw JSON string or number.";
    ];
  }
