(* TODO: revise low quality AI code *)
type option_ = {
  value: string;
  label: string;
}

type t = {
  kind: string;
  id: string;
  label: string;
  options: option_ list;
  selected: string option;
}

let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "select";
    intent = "Present a constrained set of options for the user to choose from.";
    instructions = "Use select when the user must pick one value from a \
                    known set. Never use a free-text input when the valid \
                    values are enumerable. Select must always be placed \
                    inside a submittable — it is a data collection \
                    component. Each option requires both a value (machine \
                    identifier) and a label (human readable). Set selected \
                    to the value of the default or pre-filled option if \
                    one applies.";
    fields = [
      kind_field "select";
      id_field "select";
      string_field "label" "Visible label for this selection.";
      array_field "options" "Array of { value: string, label: string } objects.";
      optional_string_field "selected" "Value of the pre-selected option. Omit if none.";
    ];
  }
