open Types
open Utils.Log

let catch throwable = 
  try throwable ()
  with err -> 
    debug "[ribosome parsing] Soft failure - Parsing template instance soft failed: " err;
    Broken (Soft "Template parse failed")

let parse_template json =
  let open Melange_json.Of_json in
  try 
  match field "kind" string json with
  | "image" -> catch (fun () -> Image (image_of_json json))
  | "text" -> catch (fun () -> Text (text_of_json json))
  | "input" -> catch (fun () -> Input (input_of_json json))
  | "submittable" -> catch (fun () -> Submittable (submittable_of_json json))
  | "container" -> catch (fun () -> Container (container_of_json json))
  | kind -> 
    debug "[ribosome parsing] Soft failure - Unknown template kind" kind;
    Broken (Soft "Unknown template")
  with err ->
    debug "[ribosome parsing] Soft failure -" (Printexc.to_string err);
    Broken (Soft "Template parse failure")

let serialise_json data = 
  try 
    Ok (Melange_json.of_string data)
  with err -> 
    Js.Console.error2 "[ribosome parsing] Hard failure - Failed to parse invalid JSON: " data;
    Error (Printexc.to_string err)

type extract_children_result = 
  | Has of Melange_json.t list
  | Corrupt of string
  | Absent

let validate_all_objects arr =
  let exception Found of int in
  try
    Array.iteri (fun i item ->
      match Js.Json.decodeObject item with
      | None -> raise (Found i)
      | Some _ -> ()
    ) arr;
    Ok arr
  with Found i -> 
    Error (Printf.sprintf "Item at index %d is not an object" i)

let decode_object json =
  match Js.Json.decodeObject json with 
    | Some obj -> Ok obj
    | None ->
      let string_value = Melange_json.to_string json in
      Js.Console.error2 "[ribosome parsing] Hard failure - Failed to decode JSON: " string_value;
      Error ("Failed to decode json: " ^ string_value)

let extract_children json = 
  match decode_object json with 
  | Ok obj ->  
    (match Js.Dict.get obj "children" with
    | Some serialised_array -> 
      (match Js.Json.decodeArray serialised_array with
      | Some array -> 
          (match validate_all_objects array with 
          | Ok array -> Has (Array.to_list array)
          | Error e -> Corrupt e)
      | None -> Corrupt (Melange_json.to_string serialised_array))
    | None -> Absent)
  | Error e -> Corrupt e

let rec expand_template json = 
  match extract_children json with 
  | Absent -> parse_template json
  | Corrupt e -> Broken (Hard e)
  | Has children -> 
    let decoded_children = List.map expand_template children in
    match parse_template json with
    | Container container -> 
      let decoded_with_children = Container { container with children = decoded_children } in
      decoded_with_children
    | _ -> Broken (Hard "Encounterd non-container with children")

let parse_data data = 
  Result.map expand_template (serialise_json data) 
