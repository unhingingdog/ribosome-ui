let optional_field name decoder json =
  match Js.Json.decodeObject json with
  | None -> None
  | Some obj ->
    match Js.Dict.get obj name with
    | None -> None
    | Some value -> Some (decoder value)
