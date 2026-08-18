type input_value = Int of int | String of string

type t = {
  kind: string;
  id: string;
  value: input_value option
}

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
