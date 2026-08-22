let not_found target_id = "target id not found: " ^ target_id

let rec patch ~target_id ~replacement tree : (Template.t, string) result =
  if Template.id tree = target_id then Ok replacement
  else
    match tree with
    | Template.Container c -> (
        match patch_in_children ~target_id ~replacement c.children with
        | Ok new_children ->
            Ok (Template.Container { c with children = new_children })
        | Error e -> Error e)
    | Template.List l -> (
        match patch_in_children ~target_id ~replacement l.children with
        | Ok new_children ->
            Ok (Template.List { l with children = new_children })
        | Error e -> Error e)
    | _ -> Error (not_found target_id)

and patch_in_children ~target_id ~replacement children :
    (Template.t list, string) result =
  let rec loop acc = function
    | [] -> Error (not_found target_id)
    | child :: rest -> (
        match patch ~target_id ~replacement child with
        | Ok new_child -> Ok (Stdlib.List.rev acc @ (new_child :: rest))
        | Error _ -> loop (child :: acc) rest)
  in
  loop [] children
