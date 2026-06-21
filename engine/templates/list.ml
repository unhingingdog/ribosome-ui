open Melange_json.Primitives

type 'template t = {
  kind: string;
  id: string;
  ordered: bool option;
  children: 'template list;
}

let deserialise json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    ordered = Helpers.optional_field "ordered" bool json;
    children = [];
  }

let serialise template child_serialiser =
  let base = [
    ("kind", string_to_json template.kind);
    ("id", string_to_json template.id);
    ("children", list_to_json child_serialiser template.children);
  ] in
  let fields =
    match template.ordered with
    | Some ordered -> base @ [("ordered", bool_to_json ordered)]
    | None -> base
  in
  Js.Json.object_ (Js.Dict.fromList fields)

let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "list";
    intent = "Represent a collection of parallel items.";
    instructions = "Use list when children are semantically parallel — \
                    the same kind of thing repeated. A set of flight \
                    results, a set of product cards, a set of menu items \
                    are all lists. Do not use list for layout grouping — \
                    use container for that. Set ordered to true only when \
                    sequence carries meaning (steps, rankings). Omit \
                    ordered otherwise.";
    fields = [
      kind_field "list";
      id_field "list";
      template_list_field "children" "Parallel items in this collection.";
      optional_bool_field "ordered" "True if sequence is meaningful. Omit if unordered.";
    ];
  }
