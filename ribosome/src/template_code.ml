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

let decode_highlight json =
  let open Codec_decode in
  let* start_line = field "start_line" int json in
  let* end_line = field "end_line" int json in
  let* tone = field "tone" Template_tone.decode json in
  Ok { start_line; end_line; tone }

let encode_highlight h =
  Codec_encode.obj
    [
      ("start_line", `Int h.start_line);
      ("end_line", `Int h.end_line);
      ("tone", Template_tone.encode h.tone);
    ]

let decode json =
  let open Codec_decode in
  let* id = field "id" string json in
  let* path = field "path" string json in
  let* language = field "language" string json in
  let* line_start = field "line_start" int json in
  let* source = field "source" string json in
  let* highlights = field "highlights" (list decode_highlight) json in
  Ok { id; path; language; line_start; source; highlights }

let encode t =
  Codec_encode.obj
    [
      ("kind", `String "code");
      ("id", `String t.id);
      ("path", `String t.path);
      ("language", `String t.language);
      ("line_start", `Int t.line_start);
      ("source", `String t.source);
      ("highlights", `List (Stdlib.List.map encode_highlight t.highlights));
    ]

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
