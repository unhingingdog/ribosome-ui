open Template_definition

type field = FieldInput of Template_input.t | FieldSelect of Template_select.t
type t = { id : string; value : field list; button : Template_button.t option }

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
