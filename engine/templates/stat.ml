open Melange_json.Primitives

type t = {
  kind: string;
  id: string;
  label: string;
  value: string;
  secondary: string option;
}

let deserialise json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    label = field "label" string json;
    value = field "value" string json;
    secondary = Helpers.optional_field "secondary" string json;
  }

let serialise (stat: t) =
  let base = [
    ("kind", string_to_json stat.kind);
    ("id", string_to_json stat.id);
    ("label", string_to_json stat.label);
    ("value", string_to_json stat.value);
  ] in
  let fields =
    match stat.secondary with
    | Some secondary -> base @ [("secondary", string_to_json secondary)]
    | None -> base
  in
  Js.Json.object_ (Js.Dict.fromList fields)


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
