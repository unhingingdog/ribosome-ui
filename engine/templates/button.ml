open Melange_json.Primitives

type action =
  | Navigate of string
  | Submit
  | Custom of string

let deserialise_action json =
  match Js.Json.decodeString json with
  | Some "Submit" -> Submit
  | Some s when String.length s > 0 ->
    if String.length s >= 9 && String.sub s 0 9 = "Navigate:" then
      Navigate (String.sub s 9 (String.length s - 9))
    else Custom s
  | _ -> failwith "expected action string"

type t = {
  kind: string;
  id: string;
  label: string;
  action: action;
  disabled: bool option;
}

let deserialise json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    label = field "label" string json;
    action = field "action" deserialise_action json;
    disabled = Helpers.optional_field "disabled" bool json;
  }

let serialise (template: t) (clicked: bool option) =
  let _clicked = match clicked with
  | Some v -> v 
  | None -> false in
  Js.Json.object_ (Js.Dict.fromList [
    ("kind", string_to_json template.kind); 
    ("id", string_to_json template.id); 
    ("label", string_to_json template.label); 
    ("clicked", bool_to_json _clicked); 
  ])

let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "button";
    intent = "Trigger a standalone action that does not collect data.";
    instructions = "Use button for navigation, secondary actions, and \
                    toggle-style interactions that do not require a form. \
                    Do not use button as the submit control inside a \
                    submittable — submittable has its own implicit submit. \
                    Set action to Submit only when the button is the \
                    primary call to action on a standalone screen with no \
                    submittable.";
    fields = [
      kind_field "button";
      id_field "button";
      string_field "label" "Visible button label.";
      string_field "action" "One of: Submit | Navigate:<url> | <custom string>.";
      optional_bool_field "disabled" "Whether the button is non-interactive. Omit if false.";
    ];
  }
