open Template_definition

type direction = Vertical | Horizontal
type 'a t = { id : string; direction : direction; children : 'a list }

let decode_direction json =
  Codec_decode.enum [ ("Vertical", Vertical); ("Horizontal", Horizontal) ] json

let encode_direction = function
  | Vertical -> `String "Vertical"
  | Horizontal -> `String "Horizontal"

let decode_child decode_template json =
  let open Codec_decode in
  let* id = field "id" string json in
  let* direction = field "direction" decode_direction json in
  let* children = field "children" (list decode_template) json in
  Ok { id; direction; children }

let encode_child encode_template t =
  Codec_encode.obj
    [
      ("kind", `String "container");
      ("id", `String t.id);
      ("direction", encode_direction t.direction);
      ("children", `List (Stdlib.List.map encode_template t.children));
    ]

let definition : Template_definition.t =
  {
    kind = "container";
    scope = TopLevel;
    intent = "Group one or more templates into a nested rendered section.";
    instructions =
      "Use container for layout, grouping, and nesting other available \
       templates.";
    fields =
      [
        kind_field "container";
        id_field "container";
        string_field "direction" "One of: Vertical | Horizontal.";
        template_list_field "children"
          "Child templates to render inside this container.";
      ];
  }
