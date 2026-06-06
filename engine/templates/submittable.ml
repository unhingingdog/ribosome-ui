open Melange_json.Primitives

type t = {
  kind: string;
  id: string;
  value: Input.t list;
} [@@deriving json]

let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "submittable";
    intent = "Present a submit-capable interaction that can start the next model turn.";
    instructions = "Use submittable when the user needs to provide data or make a choice before continuing.";
    fields = [
      kind_field "submittable";
      id_field "submittable template";
      input_list_field "value" "Inputs included in this submit-capable interaction.";
    ];
  }
