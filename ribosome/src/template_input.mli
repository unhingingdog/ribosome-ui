type input_value = Int of int | String of string
type t = { id : string; value : input_value option }

val definition : Template_definition.t
val decode : Yojson.Safe.t -> (t, Codec_error.t) result
val encode : t -> Yojson.Safe.t
