open Types
open Utils.Log

let catch throwable = 
  try Some (throwable ()) 
  with err -> 
    debug "[ribosome parsing] Soft failure - Parsing template instance soft failed: " err;
    None 

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
    None
  with err ->
    debug "[ribosome parsing] Soft failure -" (Printexc.to_string err);
    None

let serialise_json data = 
  try 
    Ok (Melange_json.of_string data)
  with err -> 
    Js.Console.error2 "[ribosome parsing] Hard failure - Failed to parse invalid JSON: " data;
    Error (Printexc.to_string err)

let attempt_template_parse data =
  Result.map parse_template (serialise_json data)

