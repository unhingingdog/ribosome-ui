open Template_definition

type t = {
  id : string;
  label : string;
  value : string;
  secondary : string option;
}

let definition : Template_definition.t =
  {
    kind = "stat";
    scope = TopLevel;
    intent = "Display a single prominent metric or data point with a label.";
    instructions =
      "Use stat for a scalar value that deserves visual prominence — price, \
       duration, distance, score, count. The label describes what the value \
       represents. The value is the formatted display string including any \
       units. Use secondary for a supporting detail. Do not use stat for body \
       text.";
    fields =
      [
        kind_field "stat";
        id_field "stat";
        string_field "label" "Describes what the value represents.";
        string_field "value"
          "Formatted display value including units if applicable.";
        optional_string_field "secondary"
          "Supporting detail, comparison, or qualifier. Omit if none.";
      ];
  }
