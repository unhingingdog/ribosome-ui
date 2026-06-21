open Melange_json.Primitives

type t =
  | Soft  of string
  | Hard of string

let deserialise json =
  let open Melange_json.Of_json in
  Hard (field "details" string json)

let serialise (template: t) =
  match template with
  | Soft message | Hard message -> 
    Js.Json.object_ (Js.Dict.fromList [
      ("kind", string_to_json "error"); 
      ("details", string_to_json message)
    ])
