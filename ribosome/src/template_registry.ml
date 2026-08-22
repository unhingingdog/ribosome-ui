let all : Template_definition.t list =
  [
    Template_text.definition;
    Template_image.definition;
    Template_badge.definition;
    Template_stat.definition;
    Template_divider.definition;
    Template_diagram.definition;
    Template_code.definition;
    Template_container.definition;
    Template_list.definition;
    Template_submittable.definition;
    Template_input.definition;
    Template_select.definition;
    Template_button.definition;
  ]

let top_level =
  Stdlib.List.filter (fun (d : Template_definition.t) -> d.scope = TopLevel) all

let nested_only =
  Stdlib.List.filter
    (fun (d : Template_definition.t) -> d.scope = NestedOnly)
    all

let for_kind kind =
  Stdlib.List.find_opt (fun (d : Template_definition.t) -> d.kind = kind) all

let for_kinds kinds =
  Stdlib.List.filter_map
    (fun kind ->
      Stdlib.List.find_opt
        (fun (d : Template_definition.t) -> d.kind = kind)
        all)
    kinds
