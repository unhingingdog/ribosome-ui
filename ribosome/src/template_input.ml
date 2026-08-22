open Template_definition

type input_value = Int of int | String of string
type t = { id : string; value : input_value option }

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
