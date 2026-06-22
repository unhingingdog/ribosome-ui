open Melange_json.Primitives
open Types

type submitted_value = SubmittedInt of int | SubmittedString of string [@@deriving json]
type submitted_input = {
  id: string;
  value: submitted_value;
} [@@deriving json]

type submission_payload = {
  template_id: string;
  values: submitted_input list;
} [@@deriving json]

let rec match_input_to_node id (inputs: submitted_input list) = match inputs with
  | [] -> None
  | h::lst -> if h.id = id then Some h else match_input_to_node id lst

let inject_user_input_into_field (field: Templates.Submittable.field) (inputs: submitted_input list) =
  match field with
  | Templates.Submittable.FieldInput input ->
      Templates.Submittable.FieldInput (
        match match_input_to_node input.id inputs with
        | Some { id = _; value = SubmittedString s } -> { input with value = Some (String s) }
        | Some { id = _; value = SubmittedInt s } -> { input with value = Some (Int s) }
        | _ -> input
      )
  | Templates.Submittable.FieldSelect select ->
      Templates.Submittable.FieldSelect (
        match match_input_to_node select.id inputs with
        | Some { id = _; value = SubmittedString s } -> { select with selected = Some s }
        | _ -> select
      )

let rec inject_user_input (template: template) (inputs: submitted_input list) =
  match template with 
    | Submittable t ->
      Submittable { t with value = List.map (fun f -> inject_user_input_into_field f inputs) t.value }
    | Container t ->
      Container { t with children = List.map (fun child -> inject_user_input child inputs) t.children }
    | List t ->
      List { t with children = List.map (fun child -> inject_user_input child inputs) t.children }
    | other -> other 

let rec serialise_template (template: template) =
  match template with 
    | Image data -> Templates.Image.serialise data 
    | Text data -> Templates.Text.serialise data
    | Badge data -> Templates.Badge.serialise data 
    | Stat data -> Templates.Stat.serialise data 
    | Divider data -> Templates.Divider.serialise data 
    | Broken data -> Templates.Broken.serialise data 
    | Button data -> Templates.Button.serialise data None
    | Submittable data -> Templates.Submittable.serialise data
    | Container data -> Templates.Container.serialise data (fun child -> serialise_template child)
    | List data -> Templates.List.serialise data (fun child -> serialise_template child) 


(*
let catch throwable = 
  try throwable ()
  with err -> 
    debug "[ribosome parsing] Soft failure - Parsing template instance soft failed: " err;
    Broken (Soft "Template parse failed")

let parse_template json =
  let open Melange_json.Of_json in
  try 
  debug "[ribosome parsing] parse_template kind" (field "kind" string json);
  match field "kind" string json with
  | "image" -> catch (fun () -> Image (deserialise_image json))
  | "text" -> catch (fun () -> Text (deserialise_text json))
  | "input" -> catch (fun () -> Input (deserialise_input json))
  | "submittable" -> catch (fun () -> Submittable (deserialise_submittable json))
  | "container" -> catch (fun () -> Container (deserialise_container json))
  | "button" -> catch (fun () -> Button (deserialise_button json))
  | "select" -> catch (fun () -> Select (deserialise_select json))
  | "badge" -> catch (fun () -> Badge (deserialise_badge json))
  | "list" -> catch (fun () -> List (deserialise_template_list json))
  | "stat" -> catch (fun () -> Stat (deserialise_stat json))
  | "divider" -> catch (fun () -> Divider (deserialise_divider json))
  | kind -> 
    debug "[ribosome parsing] Soft failure - Unknown template kind" kind;
    Broken (Soft "Unknown template")
  with err ->
    debug "[ribosome parsing] Soft failure -" (Printexc.to_string err);
    Broken (Soft "Template parse failure")


let rec expand_template json = 
  match extract_children json with 
  | Absent ->
    debug1 "[ribosome parsing] leaf template";
    parse_template json
  | Corrupt e ->
    debug "[ribosome parsing] corrupt children" e;
    Broken (Hard e)
  | Has children -> 
    debug "[ribosome parsing] expanding children" (List.length children);
    let decoded_children = List.map expand_template children in
    match parse_template json with
    | Container container -> 
      let decoded_with_children = Container { container with children = decoded_children } in
      decoded_with_children
    | List list ->
      let decoded_with_children = List { list with children = decoded_children } in
      decoded_with_children
    | _ -> Broken (Hard "Encountered template with unsupported children")

*)
