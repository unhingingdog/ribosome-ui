val definition : Template_definition.t

type highlight = { start_line : int; end_line : int; tone : Template_tone.t }

type t = {
  id : string;
  path : string;
  language : string;
  line_start : int;
  source : string;
  highlights : highlight list;
}

val decode_highlight : Yojson.Safe.t -> (highlight, Codec_error.t) result
val encode_highlight : highlight -> Yojson.Safe.t
val decode : Yojson.Safe.t -> (t, Codec_error.t) result
val encode : t -> Yojson.Safe.t
