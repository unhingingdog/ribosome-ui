type field =
  | FieldInput of Input.t
  | FieldSelect of Select.t

type t = {
  kind: string;
  id: string;
  value: field list;
  button: Button.t option;
}

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
