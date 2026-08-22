open Template_definition

type option_ = { value : string; label : string }

type t = {
  id : string;
  label : string;
  options : option_ list;
  selected : string option;
}

let definition : Template_definition.t =
  {
    kind = "select";
    scope = NestedOnly;
    intent = "Present a constrained set of options for the user to choose from.";
    instructions =
      "Use select when the user must pick one value from a known set. Never \
       use a free-text input when the valid values are enumerable. Select must \
       always be placed inside a submittable. Each option requires both a \
       value (machine identifier) and a label (human readable). Set selected \
       to the value of the default or pre-filled option if one applies.";
    fields =
      [
        kind_field "select";
        id_field "select";
        string_field "label" "Visible label for this selection.";
        array_field "options"
          "Array of { value: string, label: string } objects.";
        optional_string_field "selected"
          "Value of the pre-selected option. Omit if none.";
      ];
  }

let decode_option json =
  let open Codec_decode in
  let* value = field "value" string json in
  let* label = field "label" string json in
  Ok { value; label }

let encode_option o =
  Codec_encode.obj [ ("value", `String o.value); ("label", `String o.label) ]

let decode json =
  let open Codec_decode in
  let* id = field "id" string json in
  let* label = field "label" string json in
  let* options = field "options" (list decode_option) json in
  let* selected = optional_field "selected" string json in
  Ok { id; label; options; selected }

let encode t =
  Codec_encode.obj
    ([
       ("kind", `String "select");
       ("id", `String t.id);
       ("label", `String t.label);
       ("options", `List (Stdlib.List.map encode_option t.options));
     ]
    @ Codec_encode.optional "selected" t.selected (fun s -> `String s) [])
