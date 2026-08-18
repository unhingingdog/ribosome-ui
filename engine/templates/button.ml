type action =
  | Navigate of string
  | Submit
  | Custom of string

type t = {
  kind: string;
  id: string;
  label: string;
  action: action;
  disabled: bool option;
}

let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "button";
    intent = "Trigger an action inside a submittable.";
    instructions = "Use button ONLY inside a submittable template's button \
                    field. Do NOT emit button as a standalone template. \
                    A submittable can include one optional button for \
                    secondary actions like navigation or toggles.";
    fields = [
      kind_field "button";
      id_field "button";
      string_field "label" "Visible button label.";
      string_field "action" "One of: Submit | Navigate:<url> | <custom string>.";
      optional_bool_field "disabled" "Whether the button is non-interactive. Omit if false.";
    ];
  }
