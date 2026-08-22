open Template_definition

type 'a t = { id : string; ordered : bool option; children : 'a list }

let decode decode_template json =
  let open Codec_decode in
  let* id = field "id" string json in
  let* ordered = optional_field "ordered" bool json in
  let* children = field "children" (list decode_template) json in
  Ok { id; ordered; children }

let encode encode_template t =
  Codec_encode.obj
    ([
       ("kind", `String "list");
       ("id", `String t.id);
       ("children", `List (Stdlib.List.map encode_template t.children));
     ]
    @ Codec_encode.optional "ordered" t.ordered (fun b -> `Bool b) [])

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
