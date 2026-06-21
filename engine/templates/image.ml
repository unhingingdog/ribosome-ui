open Melange_json.Primitives

type t = {
  kind: string;
  id: string;
  src: string;
  alt: string;
}

let deserialise json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    src = field "src" string json;
    alt = field "alt" string json;
  }

let serialise (image: t) =
  Js.Json.object_ (Js.Dict.fromList [
    ("kind", string_to_json image.kind);
    ("id", string_to_json image.id);
    ("src", string_to_json image.src);
    ("alt", string_to_json image.alt);
  ])

let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "image";
    intent = "Display an image by URL.";
    instructions = "Use image only when visual content directly helps satisfy the user's goal.";
    fields = [
      kind_field "image";
      id_field "image";
      string_field "src" "Image URL.";
      string_field "alt" "Accessible description of the image.";
    ];
  }
