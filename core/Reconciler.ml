open Types

type reconcile_result =
  | Found of template
  | NotFound of template

let rec reconcile curr patch =
  if id_of_template curr = id_of_template patch then
    Found patch
  else
    match curr with
    | Container container ->
      (match reconcile_children container.children patch with
       | Some children -> Found (Container { container with children })
       | None -> NotFound curr)
    | List lst ->
      (match reconcile_children lst.children patch with
       | Some children -> Found (List { lst with children })
       | None -> NotFound curr)
    | other -> NotFound other

and reconcile_children children patch =
  match children with
  | [] -> None
  | h :: t ->
    match reconcile h patch with
    | Found h' -> Some (h' :: t)
    | NotFound h' ->
      Option.map (fun t' -> h' :: t') (reconcile_children t patch)
