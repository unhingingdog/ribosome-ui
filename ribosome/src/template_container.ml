open Template_definition

type direction = Vertical | Horizontal
type 'a t = { id : string; direction : direction; children : 'a list }

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
