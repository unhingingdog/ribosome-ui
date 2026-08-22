open Template_definition

type input_value = Int of int | String of string
type t = { id : string; value : input_value option }

let decode_input_value json =
  match json with
  | `Int n -> Ok (Int n)
  | `String s -> Ok (String s)
  | _ -> Error (Codec_error.make [] WrongType "expected string or integer")

let encode_input_value = function Int n -> `Int n | String s -> `String s

let decode json =
  let open Codec_decode in
  let* id = field "id" string json in
  let* value = optional_field "value" decode_input_value json in
  Ok { id; value }

let encode t =
  Codec_encode.obj
    ([ ("kind", `String "input"); ("id", `String t.id) ]
    @ Codec_encode.optional "value" t.value encode_input_value [])

let definition : Template_definition.t =
  {
    kind = "input";
    scope = NestedOnly;
    intent = "Collect a user-editable value inside a submittable template.";
    instructions =
      "Only render input as part of a submittable template's value array.";
    fields =
      [
        kind_field "input";
        id_field "input";
        string_field "value"
          "Initial input value as a raw JSON string or number.";
      ];
  }
