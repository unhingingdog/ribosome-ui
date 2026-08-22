open Template_definition

type point = { x : int; y : int }
type size = { width : int; height : int }

type primitive =
  | Text of { text : string; position : point; tone : Template_tone.t }
  | Line of { start : point; stop : point; tone : Template_tone.t }
  | Arrow of { start : point; stop : point; tone : Template_tone.t }
  | Rectangle of { origin : point; size : size; tone : Template_tone.t }
  | Circle of { center : point; radius : int; tone : Template_tone.t }
  | Polyline of { points : point list; tone : Template_tone.t }

type t = {
  id : string;
  title : string;
  size : size;
  primitives : primitive list;
}

let definition : Template_definition.t =
  {
    kind = "diagram";
    scope = TopLevel;
    intent = "Render a vector diagram with typed drawing primitives.";
    instructions =
      "Use diagram for structured visual content — flowcharts, architecture \
       diagrams, relationship graphs. Each primitive carries a tone for \
       semantic coloring.";
    fields =
      [
        kind_field "diagram";
        id_field "diagram";
        string_field "title" "Diagram title.";
        object_field "size" "Object with width and height integer fields.";
        array_field "primitives"
          "Array of drawing primitives: text, line, arrow, rectangle, circle, \
           polyline. Each carries a tone: Default | Positive | Negative | \
           Warning | Info.";
      ];
  }
