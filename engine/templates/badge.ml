open Melange_json.Primitives

type badge_variant = Neutral | Success | Warning | Error | Info

let badge_variant_of_string = function
  | "Neutral" -> Neutral
  | "Success" -> Success
  | "Warning" -> Warning
  | "Error" -> Error
  | "Info" -> Info
  | v -> failwith ("unknown badge variant: " ^ v)

let deserialise_badge_variant json =
  match Js.Json.decodeString json with
  | Some s -> badge_variant_of_string s
  | None -> failwith "expected badge variant string"

type t = {
  kind: string;
  id: string;
  label: string;
  variant: badge_variant;
}

let deserialise json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    label = field "label" string json;
    variant = field "variant" deserialise_badge_variant json;
  }

let serialise (template: t) =
  Js.Json.object_ (Js.Dict.fromList [
    ("kind", string_to_json template.kind);
    ("id", string_to_json template.id);
    ("label", string_to_json template.label);
    ("variant", string_to_json (match template.variant with
      | Neutral -> "Neutral"
      | Success -> "Success"
      | Warning -> "Warning"
      | Error -> "Error"
      | Info -> "Info"));
  ])

let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "badge";
    intent = "Display a small semantic status label.";
    instructions = "Use badge for status indicators, tags, and short \
                    categorical labels that carry semantic weight beyond \
                    plain text. Choose the variant that matches the \
                    semantic meaning: Success for confirmed or positive \
                    states, Warning for caution, Error for failures or \
                    blockers, Info for neutral informational labels, \
                    Neutral as the default. Do not use badge for long \
                    text — labels should be one to three words.";
    fields = [
      kind_field "badge";
      id_field "badge";
      string_field "label" "Short status label, one to three words.";
      string_field "variant" "One of: Neutral | Success | Warning | Error | Info.";
    ];
  }
