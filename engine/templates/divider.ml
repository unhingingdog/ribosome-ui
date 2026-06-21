open Melange_json.Primitives

type t = {
  kind: string;
  id: string;
  label: string option;
}

let deserialise json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    label = Helpers.optional_field "label" string json;
  }

let serialise (divider: t) =
  let base = [
    ("kind", string_to_json divider.kind);
    ("id", string_to_json divider.id);
  ] in
  let fields =
    match divider.label with
    | Some label -> base @ [("label", string_to_json label)]
    | None -> base
  in
  Js.Json.object_ (Js.Dict.fromList fields)


let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "divider";
    intent = "Separate distinct sections of a layout visually.";
    instructions = "Use divider to express a meaningful boundary between \
                    sections that are siblings in the layout. Do not use \
                    divider inside a container that already provides \
                    visual grouping — the container boundary is the \
                    separator. Omit label unless the division point has a \
                    meaningful name such as a section heading that does \
                    not warrant a full text node.";
    fields = [
      kind_field "divider";
      id_field "divider";
      optional_string_field "label" "Optional section label at the divide point. Omit if none.";
    ];
  }
