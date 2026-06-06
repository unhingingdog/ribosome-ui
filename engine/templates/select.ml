(* TODO: revise low quality AI code *)

type option_ = {
  value: string;
  label: string;
}

let option_of_json json =
  let open Melange_json.Of_json in
  {
    value = field "value" string json;
    label = field "label" string json;
  }

let options_of_array arr =
  let rec loop index result =
    if index < 0 then result
    else loop (index - 1) (option_of_json arr.(index) :: result)
  in
  loop (Array.length arr - 1) []

type t = {
  kind: string;
  id: string;
  label: string;
  options: option_ list;
  selected: string option;
}

let of_json json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    label = field "label" string json;
    options =
      field "options" (fun j ->
        match Js.Json.decodeArray j with
        | Some arr -> options_of_array arr
        | None -> failwith "expected options array"
      ) json;
    selected = Helpers.optional_field "selected" string json;
  }

let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "select";
    intent = "Present a constrained set of options for the user to choose from.";
    instructions = "Use select when the user must pick one value from a \
                    known set. Never use a free-text input when the valid \
                    values are enumerable. Select must always be placed \
                    inside a submittable — it is a data collection \
                    component. Each option requires both a value (machine \
                    identifier) and a label (human readable). Set selected \
                    to the value of the default or pre-filled option if \
                    one applies.";
    fields = [
      kind_field "select";
      id_field "select";
      string_field "label" "Visible label for this selection.";
      array_field "options" "Array of { value: string, label: string } objects.";
      optional_string_field "selected" "Value of the pre-selected option. Omit if none.";
    ];
  }
