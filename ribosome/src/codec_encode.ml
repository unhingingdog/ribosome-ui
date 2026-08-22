let optional name value encoder fields =
  match value with None -> fields | Some v -> (name, encoder v) :: fields

let obj fields = `Assoc fields
