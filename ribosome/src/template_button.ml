open Template_definition

type action = Submit | Navigate of string | Custom of string

let action_of_string = function
  | "Submit" -> Submit
  | s when String.length s >= 10 && String.sub s 0 10 = "Navigate:" ->
      Navigate (String.sub s 10 (String.length s - 10))
  | s -> Custom s

let string_of_action = function
  | Submit -> "Submit"
  | Navigate dest -> "Navigate:" ^ dest
  | Custom s -> s

type t = { id : string; label : string; action : action; disabled : bool }

let decode json =
  let open Codec_decode in
  let* id = field "id" string json in
  let* label = field "label" string json in
  let* action = field "action" string json in
  let* disabled =
    match optional_field "disabled" bool json with
    | Ok (Some b) -> Ok b
    | Ok None -> Ok false
    | Error e -> Error e
  in
  Ok { id; label; action = action_of_string action; disabled }

let encode t =
  Codec_encode.obj
    ([
       ("kind", `String "button");
       ("id", `String t.id);
       ("label", `String t.label);
       ("action", `String (string_of_action t.action));
     ]
    @ if t.disabled then [ ("disabled", `Bool true) ] else [])

let definition : Template_definition.t =
  {
    kind = "button";
    scope = NestedOnly;
    intent = "Trigger an action inside a submittable.";
    instructions =
      "Use button ONLY inside a submittable template's button field. Do NOT \
       emit button as a standalone template. A submittable can include one \
       optional button for secondary actions like navigation or toggles.";
    fields =
      [
        kind_field "button";
        id_field "button";
        string_field "label" "Visible button label.";
        string_field "action"
          "One of: Submit | Navigate:<url> | <custom string>.";
        optional_bool_field "disabled"
          "Whether the button is non-interactive. Omit if false.";
      ];
  }
