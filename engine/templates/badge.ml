type badge_variant = Neutral | Success | Warning | Error | Info

let badge_variant_of_string = function
  | "Neutral" -> Neutral
  | "Success" -> Success
  | "Warning" -> Warning
  | "Error" -> Error
  | "Info" -> Info
  | value -> failwith ("unknown badge variant: " ^ value)

let string_of_badge_variant = function
  | Neutral -> "Neutral"
  | Success -> "Success"
  | Warning -> "Warning"
  | Error -> "Error"
  | Info -> "Info"

type t = {
  kind: string;
  id: string;
  label: string;
  variant: badge_variant;
}

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
