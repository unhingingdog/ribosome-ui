type error =
  | Empty_id
  | Duplicate_id of string

let rec duplicate_ids seen duplicates = function
  | [] -> duplicates
  | id :: remaining ->
    if Stdlib.List.mem id seen then
      duplicate_ids seen (id :: duplicates) remaining
    else
      duplicate_ids (id :: seen) duplicates remaining

let validate template =
  let ids = Traversal.ids template in
  let empty_ids = Stdlib.List.filter (fun id -> id = "") ids in
  let duplicates = duplicate_ids [] [] ids in
  match empty_ids, duplicates with
  | [], [] -> Ok ()
  | _, _ ->
    Error (
      (Stdlib.List.map (fun _ -> Empty_id) empty_ids)
      @ (Stdlib.List.map (fun id -> Duplicate_id id) duplicates)
    )
