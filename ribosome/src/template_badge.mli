type badge_variant = Neutral | Success | Warning | Error | Info
type t = { id : string; label : string; variant : badge_variant }

val badge_variant_of_string : string -> badge_variant
val string_of_badge_variant : badge_variant -> string
val definition : Template_definition.t
val decode : Yojson.Safe.t -> (t, Codec_error.t) result
val encode : t -> Yojson.Safe.t
