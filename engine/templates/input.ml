open Melange_json.Primitives

type input_value = Int of int | String of string

let input_value_of_json json =
  match Js.Json.decodeString json with
  | Some value -> String value
  | None ->
    match (try Some (int_of_json json) with _ -> None) with
    | Some value -> Int value
    | None ->
      match Js.Json.decodeObject json with
      | Some obj ->
        (match Js.Dict.get obj "String", Js.Dict.get obj "Int" with
        | Some value, _ -> String (string_of_json value)
        | None, Some value -> Int (int_of_json value)
        | None, None -> failwith "expected input value string, number, { String }, or { Int }")
      | None ->
        match Js.Json.decodeArray json with
        | Some arr when Array.length arr = 2 ->
          (match Js.Json.decodeString arr.(0) with
          | Some "String" -> String (string_of_json arr.(1))
          | Some "Int" -> Int (int_of_json arr.(1))
          | _ -> failwith "expected input value tag String or Int")
        | _ -> failwith "expected input value string or number"

let input_value_to_json = function
  | Int value -> int_to_json value
  | String value -> string_to_json value

type t = {
  kind: string;
  id: string;
  value: input_value
} [@@deriving json]

let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "input";
    intent = "Collect a user-editable value inside a submittable template.";
    instructions = "Only render input as part of a submittable template's value array.";
    fields = [
      kind_field "input";
      id_field "input";
      string_field "value" "Initial input value as a raw JSON string or number.";
    ];
  }
