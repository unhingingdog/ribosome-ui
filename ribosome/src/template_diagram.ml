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
