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

let decode_point json =
  let open Codec_decode in
  let* x = field "x" int json in
  let* y = field "y" int json in
  Ok { x; y }

let encode_point p = Codec_encode.obj [ ("x", `Int p.x); ("y", `Int p.y) ]

let decode_size json =
  let open Codec_decode in
  let* width = field "width" int json in
  let* height = field "height" int json in
  Ok { width; height }

let encode_size s =
  Codec_encode.obj [ ("width", `Int s.width); ("height", `Int s.height) ]

let decode_primitive json =
  let open Codec_decode in
  let* kind = field "kind" string json in
  match kind with
  | "text" ->
      let* text = field "text" string json in
      let* position = field "position" decode_point json in
      let* tone = field "tone" Template_tone.decode json in
      Ok (Text { text; position; tone })
  | "line" ->
      let* start = field "start" decode_point json in
      let* stop = field "stop" decode_point json in
      let* tone = field "tone" Template_tone.decode json in
      Ok (Line { start; stop; tone })
  | "arrow" ->
      let* start = field "start" decode_point json in
      let* stop = field "stop" decode_point json in
      let* tone = field "tone" Template_tone.decode json in
      Ok (Arrow { start; stop; tone })
  | "rectangle" ->
      let* origin = field "origin" decode_point json in
      let* size = field "size" decode_size json in
      let* tone = field "tone" Template_tone.decode json in
      Ok (Rectangle { origin; size; tone })
  | "circle" ->
      let* center = field "center" decode_point json in
      let* radius = field "radius" int json in
      let* tone = field "tone" Template_tone.decode json in
      Ok (Circle { center; radius; tone })
  | "polyline" ->
      let* points = field "points" (list decode_point) json in
      let* tone = field "tone" Template_tone.decode json in
      Ok (Polyline { points; tone })
  | _ ->
      Error
        (Codec_error.make [ Field "kind" ] UnknownEnum
           "expected one of: text | line | arrow | rectangle | circle | \
            polyline")

let encode_primitive = function
  | Text { text; position; tone } ->
      Codec_encode.obj
        [
          ("kind", `String "text");
          ("text", `String text);
          ("position", encode_point position);
          ("tone", Template_tone.encode tone);
        ]
  | Line { start; stop; tone } ->
      Codec_encode.obj
        [
          ("kind", `String "line");
          ("start", encode_point start);
          ("stop", encode_point stop);
          ("tone", Template_tone.encode tone);
        ]
  | Arrow { start; stop; tone } ->
      Codec_encode.obj
        [
          ("kind", `String "arrow");
          ("start", encode_point start);
          ("stop", encode_point stop);
          ("tone", Template_tone.encode tone);
        ]
  | Rectangle { origin; size; tone } ->
      Codec_encode.obj
        [
          ("kind", `String "rectangle");
          ("origin", encode_point origin);
          ("size", encode_size size);
          ("tone", Template_tone.encode tone);
        ]
  | Circle { center; radius; tone } ->
      Codec_encode.obj
        [
          ("kind", `String "circle");
          ("center", encode_point center);
          ("radius", `Int radius);
          ("tone", Template_tone.encode tone);
        ]
  | Polyline { points; tone } ->
      Codec_encode.obj
        [
          ("kind", `String "polyline");
          ("points", `List (Stdlib.List.map encode_point points));
          ("tone", Template_tone.encode tone);
        ]

let decode json =
  let open Codec_decode in
  let* id = field "id" string json in
  let* title = field "title" string json in
  let* size = field "size" decode_size json in
  let* primitives = field "primitives" (list decode_primitive) json in
  Ok { id; title; size; primitives }

let encode t =
  Codec_encode.obj
    [
      ("kind", `String "diagram");
      ("id", `String t.id);
      ("title", `String t.title);
      ("size", encode_size t.size);
      ("primitives", `List (Stdlib.List.map encode_primitive t.primitives));
    ]

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
