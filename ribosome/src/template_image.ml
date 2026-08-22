open Template_definition

type t = { id : string; src : string; alt : string }

let decode json =
  let open Codec_decode in
  let* id = field "id" string json in
  let* src = field "src" string json in
  let* alt = field "alt" string json in
  Ok { id; src; alt }

let encode t =
  Codec_encode.obj
    [
      ("kind", `String "image");
      ("id", `String t.id);
      ("src", `String t.src);
      ("alt", `String t.alt);
    ]

let definition : Template_definition.t =
  {
    kind = "image";
    scope = TopLevel;
    intent = "Display an image by URL.";
    instructions =
      "Use image only when visual content directly helps satisfy the user's \
       goal.";
    fields =
      [
        kind_field "image";
        id_field "image";
        string_field "src" "Image URL.";
        string_field "alt" "Accessible description of the image.";
      ];
  }
