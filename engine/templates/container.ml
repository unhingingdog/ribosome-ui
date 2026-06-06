type 'template t = {
  kind: string;
  id: string;
  children: 'template list
}

let of_json json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    children = [];
  }

let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "container";
    intent = "Group one or more templates into a nested rendered section.";
    instructions = "Use container for layout, grouping, and nesting other available templates.";
    fields = [
      kind_field "container";
      id_field "container";
      template_list_field "children" "Child templates to render inside this container.";
    ];
  }
