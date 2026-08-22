open Template_definition

type field = FieldInput of Template_input.t | FieldSelect of Template_select.t
type t = { id : string; value : field list; button : Template_button.t option }

let decode_field json =
  match json with
  | `Assoc fields -> (
      match Stdlib.List.assoc_opt "kind" fields with
      | Some (`String "input") -> (
          match Template_input.decode json with
          | Ok input -> Ok (FieldInput input)
          | Error e -> Error e)
      | Some (`String "select") -> (
          match Template_select.decode json with
          | Ok select -> Ok (FieldSelect select)
          | Error e -> Error e)
      | Some _ | None ->
          Error
            (Codec_error.make [ Field "kind" ] WrongType
               "expected kind 'input' or 'select' for submittable field"))
  | _ -> Error (Codec_error.make [] WrongType "expected object for field")

let encode_field = function
  | FieldInput input -> Template_input.encode input
  | FieldSelect select -> Template_select.encode select

let decode json =
  let open Codec_decode in
  let* id = field "id" string json in
  let* value = field "value" (list decode_field) json in
  let* button = optional_field "button" Template_button.decode json in
  Ok { id; value; button }

let encode t =
  Codec_encode.obj
    ([
       ("kind", `String "submittable");
       ("id", `String t.id);
       ("value", `List (Stdlib.List.map encode_field t.value));
     ]
    @ Codec_encode.optional "button" t.button Template_button.encode [])

let definition : Template_definition.t =
  {
    kind = "submittable";
    scope = TopLevel;
    intent =
      "Present a submit-capable interaction that can start the next model turn.";
    instructions =
      "Use submittable when the user needs to provide data or make a choice \
       before continuing. Its value array holds input and select nodes only.";
    fields =
      [
        kind_field "submittable";
        id_field "submittable template";
        input_list_field "value"
          "Input and select nodes included in this submit-capable interaction.";
      ];
  }
