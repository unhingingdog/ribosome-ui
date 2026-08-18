type direction = Vertical | Horizontal

let direction_of_string = function
  | "vertical" -> Vertical
  | "horizontal" -> Horizontal
  | value -> failwith ("unknown container direction: " ^ value)

let string_of_direction = function
  | Vertical -> "vertical"
  | Horizontal -> "horizontal"

type 'template t = {
  kind: string;
  id: string;
  direction: direction;
  children: 'template list
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
    TemplateDefinitionTypes.string_field
      "direction"
      "One of: vertical | horizontal.";
    {
      name = "children";
      field_type = TemplateDefinitionTypes.TemplateList;
      required = true;
      instructions = "Child templates to render inside this container.";
    };
  ];
}
