open Melange_json.Primitives

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

let deserialise json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    direction = field "direction" (fun value -> direction_of_string (string value)) json;
    children = [];
  }

let serialise template child_serialiser =
  let serialised_children = list_to_json child_serialiser template.children in
  Js.Json.object_ (Js.Dict.fromList [
    ("kind", string_to_json template.kind); 
    ("id", string_to_json template.id); 
    ("direction", string_to_json (string_of_direction template.direction));
    ("children", serialised_children); 
  ])


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
