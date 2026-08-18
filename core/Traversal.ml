open Types

let template_children = function
  | Container container -> container.children
  | List list -> list.children
  | Submittable _ | Image _ | Text _ | Broken _ | Badge _ | Stat _ | Divider _ -> []

let rec fold_templates f initial template =
  let next = f initial template in
  Stdlib.List.fold_left (fold_templates f) next (template_children template)

let append_submittable_ids ids submittable =
  let field_ids = Stdlib.List.map (function
    | FieldInput input -> input.id
    | FieldSelect select -> select.id
  ) submittable.value in
  let button_ids = match submittable.button with
    | Some button -> [button.id]
    | None -> []
  in
  ids @ (submittable.id :: field_ids @ button_ids)

let ids template =
  let add ids = function
    | Submittable submittable -> append_submittable_ids ids submittable
    | Broken _ -> ids
    | node -> ids @ [id_of_template node]
  in
  fold_templates add [] template
