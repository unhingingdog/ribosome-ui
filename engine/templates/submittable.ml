open Melange_json.Primitives

type field =
  | FieldInput of Input.t
  | FieldSelect of Select.t

let deserialise_field json =
  match Melange_json.Of_json.(field "kind" string json) with
  | "select" -> FieldSelect (Select.deserialise json)
  | _ -> FieldInput (Input.deserialise json)

let serialise_field = function
  | FieldInput input -> Input.serialise input
  | FieldSelect select -> Select.serialise select select.selected

type t = {
  kind: string;
  id: string;
  value: field list;
  button: Button.t option;
}

let deserialise json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    value = field "value" (list deserialise_field) json;
    button = Helpers.optional_field "button" Button.deserialise json;
  }

let serialise (submittable: t) =
  let base = [
    ("kind", string_to_json submittable.kind);
    ("id", string_to_json submittable.id);
    ("value", list_to_json serialise_field submittable.value);
  ] in
  let fields = match submittable.button with
    | Some button -> base @ [("button", Button.serialise button None)]
    | None -> base
  in
  Js.Json.object_ (Js.Dict.fromList fields)

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
