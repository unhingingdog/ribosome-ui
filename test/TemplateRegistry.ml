let all_definitions : TemplateDefinitionTypes.template_definition list =
  let open TemplateDefinitionTypes in
  [
    {
      kind = "text";
      intent = "Display textual content to the user.";
      instructions = "Use text for headings, paragraphs, labels, explanations, and short feedback.";
      fields = [
        kind_field "text";
        id_field "text node";
        string_field "text_type" "One of: Paragraph | H1 | H2 | H3 | H4 | H5 | H6.";
        string_field "value" "Text content to render.";
      ];
    };
    {
      kind = "container";
      intent = "Group one or more templates into a nested rendered section.";
      instructions = "Use container for layout, grouping, and nesting other available templates.";
      fields = [
        kind_field "container";
        id_field "container";
        template_list_field "children" "Child templates to render inside this container.";
      ];
    };
  ]

let definition_for_kind kind =
  let rec loop = function
    | [] -> None
    | (definition : TemplateDefinitionTypes.template_definition) :: rest ->
      if definition.kind = kind then Some definition
      else loop rest
  in
  loop all_definitions

let definitions_for_kinds kinds =
  let rec reverse result = function
    | [] -> result
    | definition :: rest -> reverse (definition :: result) rest
  in
  let rec loop definitions = function
    | [] -> reverse [] definitions
    | kind :: rest ->
      match definition_for_kind kind with
      | None -> loop definitions rest
      | Some definition -> loop (definition :: definitions) rest
  in
  loop [] kinds
