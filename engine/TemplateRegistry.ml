let all_definitions : TemplateDefinitionTypes.template_definition list = [
  Templates.Text.definition;
  Templates.Input.definition;
  Templates.Submittable.definition;
  Templates.Image.definition;
  Templates.Container.definition;
  Templates.Button.definition;
  Templates.Select.definition;
  Templates.Badge.definition;
  Templates.List.definition;
  Templates.Stat.definition;
  Templates.Divider.definition;
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
