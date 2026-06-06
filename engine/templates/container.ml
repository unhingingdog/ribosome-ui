(* TODO: revise low quality AI code *)

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

let definition : TemplateDefinitionTypes.template_definition = {
  kind = "container";
  intent = "Group one or more templates into a nested rendered section.";
  instructions = "Use container for layout, grouping, and nesting other available templates.";
  fields = [
    {
      name = "kind";
      field_type = TemplateDefinitionTypes.StringField;
      required = true;
      instructions = "Always container.";
    };
    {
      name = "id";
      field_type = TemplateDefinitionTypes.StringField;
      required = true;
      instructions = "Stable id for this container.";
    };
    {
      name = "children";
      field_type = TemplateDefinitionTypes.TemplateList;
      required = true;
      instructions = "Child templates to render inside this container.";
    };
  ];
}
