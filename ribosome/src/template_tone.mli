type t = Default | Positive | Negative | Warning | Info

val of_string : string -> t
val to_string : t -> string
val decode : Yojson.Safe.t -> (t, Codec_error.t) result
val encode : t -> Yojson.Safe.t
