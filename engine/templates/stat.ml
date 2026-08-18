type t = {
  kind: string;
  id: string;
  label: string;
  value: string;
  secondary: string option;
}

let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "stat";
    intent = "Display a single prominent metric or data point with a label.";
    instructions = "Use stat for a scalar value that deserves visual \
                    prominence — price, duration, distance, score, count. \
                    The label describes what the value represents. The \
                    value is the formatted display string including any \
                    units. Use secondary for a supporting detail such as \
                    a comparison, trend, or qualifier. Do not use stat \
                    for body text or explanations — use text for that.";
    fields = [
      kind_field "stat";
      id_field "stat";
      string_field "label" "Describes what the value represents.";
      string_field "value" "Formatted display value including units if applicable.";
      optional_string_field "secondary" "Supporting detail, comparison, or qualifier. Omit if none.";
    ];
  }
