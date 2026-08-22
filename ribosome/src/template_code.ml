open Template_definition

type highlight = { start_line : int; end_line : int; tone : Template_tone.t }

type t = {
  id : string;
  path : string;
  language : string;
  line_start : int;
  source : string;
  highlights : highlight list;
}

let definition : Template_definition.t =
  {
    kind = "code";
    scope = TopLevel;
    intent = "Display source code with typed line highlights.";
    instructions =
      "Use code to show source excerpts with optional highlighted line ranges. \
       Each highlight carries a tone for semantic coloring.";
    fields =
      [
        kind_field "code";
        id_field "code";
        string_field "path" "File path for display.";
        string_field "language" "Language identifier for syntax highlighting.";
        number_field "line_start"
          "1-based line number of the first source line.";
        string_field "source" "Raw source text.";
        array_field "highlights"
          "Array of { start_line, end_line, tone } objects. Tone: Default | \
           Positive | Negative | Warning | Info.";
      ];
  }
