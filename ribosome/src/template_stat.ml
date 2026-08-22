open Template_definition

type t = {
  id : string;
  label : string;
  value : string;
  secondary : string option;
}

let decode json =
  let open Codec_decode in
  let* id = field "id" string json in
  let* label = field "label" string json in
  let* value = field "value" string json in
  let* secondary = optional_field "secondary" string json in
  Ok { id; label; value; secondary }

let encode t =
  Codec_encode.obj
    ([
       ("kind", `String "stat");
       ("id", `String t.id);
       ("label", `String t.label);
       ("value", `String t.value);
     ]
    @ Codec_encode.optional "secondary" t.secondary (fun s -> `String s) [])

let definition : Template_definition.t =
  {
    kind = "stat";
    scope = TopLevel;
    intent = "Display a single prominent metric or data point with a label.";
    instructions =
      "Use stat for a scalar value that deserves visual prominence — price, \
       duration, distance, score, count. The label describes what the value \
       represents. The value is the formatted display string including any \
       units. Use secondary for a supporting detail. Do not use stat for body \
       text.";
    fields =
      [
        kind_field "stat";
        id_field "stat";
        string_field "label" "Describes what the value represents.";
        string_field "value"
          "Formatted display value including units if applicable.";
        optional_string_field "secondary"
          "Supporting detail, comparison, or qualifier. Omit if none.";
      ];
  }
