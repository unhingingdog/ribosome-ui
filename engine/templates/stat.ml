(* TODO: revise low quality AI code *)

type t = {
  kind: string;
  id: string;
  label: string;
  value: string;
  secondary: string option;
}

let of_json json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    label = field "label" string json;
    value = field "value" string json;
    secondary = Helpers.optional_field "secondary" string json;
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
