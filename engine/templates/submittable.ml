open Melange_json.Primitives

type field =
  | FieldInput of Input.t
  | FieldSelect of Select.t

let field_of_json json =
  match Melange_json.Of_json.(field "kind" string json) with
  | "select" -> FieldSelect (Select.of_json json)
  | _ -> FieldInput (Input.of_json json)

let field_to_json = function
  | FieldInput input -> Input.to_json input
  | FieldSelect select -> Select.to_json select

type t = {
  kind: string;
  id: string;
  value: field list;
}

let of_json json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    value = field "value" (list field_of_json) json;
  }

let to_json (submittable: t) =
  Js.Json.object_ (Js.Dict.fromArray [|
    ("kind", string_to_json submittable.kind);
    ("id", string_to_json submittable.id);
    ("value", list_to_json field_to_json submittable.value);
  |])

let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "submittable";
    intent = "Present a submit-capable interaction that can start the next model turn.";
    instructions = "Use submittable when the user needs to provide data or make a choice before continuing. \
                    Its value array holds input and select nodes only — inputs for free-form text, \
                    selects for a choice from a known set.";
    fields = [
      kind_field "submittable";
      id_field "submittable template";
      input_list_field "value" "Input and select nodes included in this submit-capable interaction.";
    ];
  }
