type t = { id : string; label : string option }

val definition : Template_definition.t
val decode : Yojson.Safe.t -> (t, Codec_error.t) result
val encode : t -> Yojson.Safe.t
