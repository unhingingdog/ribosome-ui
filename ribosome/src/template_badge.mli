type badge_variant = Neutral | Success | Warning | Error | Info

val badge_variant_of_string : string -> badge_variant
val string_of_badge_variant : badge_variant -> string

type t = { id : string; label : string; variant : badge_variant }
