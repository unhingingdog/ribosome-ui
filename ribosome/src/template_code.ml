type highlight = { start_line : int; end_line : int; tone : Template_tone.t }

type t = {
  id : string;
  path : string;
  language : string;
  line_start : int;
  source : string;
  highlights : highlight list;
}
