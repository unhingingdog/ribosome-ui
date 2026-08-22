open Template_definition

type 'a t = { id : string; ordered : bool option; children : 'a list }

let definition : Template_definition.t =
  {
    kind = "list";
    scope = TopLevel;
    intent = "Represent a collection of parallel items.";
    instructions =
      "Use list when children are semantically parallel — the same kind of \
       thing repeated. Do not use list for layout grouping — use container for \
       that. Set ordered to true only when sequence carries meaning (steps, \
       rankings). Omit ordered otherwise.";
    fields =
      [
        kind_field "list";
        id_field "list";
        template_list_field "children" "Parallel items in this collection.";
        optional_bool_field "ordered"
          "True if sequence is meaningful. Omit if unordered.";
      ];
  }
