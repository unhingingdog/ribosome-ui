open Codec_error

let ( let* ) = Result.bind

let string json : (string, t) result =
  match json with
  | `String s -> Ok s
  | _ -> Error (make [] WrongType "expected string")

let int json : (int, t) result =
  match json with
  | `Int n -> Ok n
  | _ -> Error (make [] WrongType "expected integer")

let bool json : (bool, t) result =
  match json with
  | `Bool b -> Ok b
  | _ -> Error (make [] WrongType "expected boolean")

let field name decoder json : ('a, t) result =
  match json with
  | `Assoc assoc -> (
      match Stdlib.List.assoc_opt name assoc with
      | None -> Error (make [ Field name ] MissingField "field is required")
      | Some v -> (
          match decoder v with
          | Ok a -> Ok a
          | Error e -> Error (with_path (Field name) e)))
  | _ -> Error (make [] WrongType "expected object")

let optional_field name decoder json : ('a option, t) result =
  match json with
  | `Assoc assoc -> (
      match Stdlib.List.assoc_opt name assoc with
      | None | Some `Null -> Ok None
      | Some v -> (
          match decoder v with
          | Ok a -> Ok (Some a)
          | Error e -> Error (with_path (Field name) e)))
  | _ -> Error (make [] WrongType "expected object")

let list decoder json : ('a list, t) result =
  match json with
  | `List items ->
      let rec loop index acc = function
        | [] -> Ok (Stdlib.List.rev acc)
        | item :: rest -> (
            match decoder item with
            | Ok a -> loop (index + 1) (a :: acc) rest
            | Error e -> Error (with_path (Index index) e))
      in
      loop 0 [] items
  | _ -> Error (make [] WrongType "expected array")

let enum table json : ('a, t) result =
  match json with
  | `String s -> (
      match Stdlib.List.assoc_opt s table with
      | Some v -> Ok v
      | None ->
          Error
            (make [] UnknownEnum
               ("expected one of: "
               ^ String.concat " | " (Stdlib.List.map fst table))))
  | _ -> Error (make [] WrongType "expected string")

let object_ json : (unit, t) result =
  match json with
  | `Assoc _ -> Ok ()
  | _ -> Error (make [] WrongType "expected object")
