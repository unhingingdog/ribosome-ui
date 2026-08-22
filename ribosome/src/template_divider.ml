open Template_definition

type t = { id : string; label : string option }

let decode json =
  let open Codec_decode in
  let* id = field "id" string json in
  let* label = optional_field "label" string json in
  Ok { id; label }

let encode t =
  Codec_encode.obj
    ([ ("kind", `String "divider"); ("id", `String t.id) ]
    @ Codec_encode.optional "label" t.label (fun s -> `String s) [])

let definition : Template_definition.t =
  {
    kind = "divider";
    scope = TopLevel;
    intent = "Separate distinct sections of a layout visually.";
    instructions =
      "Use divider to express a meaningful boundary between sections that are \
       siblings in the layout. Omit label unless the division point has a \
       meaningful name.";
    fields =
      [
        kind_field "divider";
        id_field "divider";
        optional_string_field "label"
          "Optional section label at the divide point. Omit if none.";
      ];
  }
