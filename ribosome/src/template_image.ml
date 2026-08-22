open Template_definition

type t = { id : string; src : string; alt : string }

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
