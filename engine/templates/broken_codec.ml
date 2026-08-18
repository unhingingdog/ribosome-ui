open Melange_json.Primitives

let deserialise json =
  let open Melange_json.Of_json in
  Broken.Hard (field "details" string json)

let serialise = function
  | Broken.Soft message | Broken.Hard message ->
    Js.Json.object_ (Js.Dict.fromList [
      ("kind", string_to_json "error");
      ("details", string_to_json message);
    ])
