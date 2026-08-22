type path_segment = Field of string | Index of int
type field_path = path_segment list
type category = MissingField | WrongType | InvalidValue | UnknownEnum
type t = { path : field_path; category : category; message : string }

let category_to_string = function
  | MissingField -> "missing field"
  | WrongType -> "wrong type"
  | InvalidValue -> "invalid value"
  | UnknownEnum -> "unknown enum value"

let format_path = function
  | [] -> "(root)"
  | segments ->
      let buf = Buffer.create 16 in
      Stdlib.List.iter
        (fun seg ->
          match seg with
          | Field name ->
              if Buffer.length buf > 0 then Buffer.add_char buf '.';
              Buffer.add_string buf name
          | Index i ->
              Buffer.add_string buf "[";
              Buffer.add_string buf (string_of_int i);
              Buffer.add_string buf "]")
        segments;
      Buffer.contents buf

let make path category message = { path; category; message }

let to_string e =
  Printf.sprintf "%s: %s — %s" (format_path e.path)
    (category_to_string e.category)
    e.message

let with_path segment e = { e with path = segment :: e.path }
