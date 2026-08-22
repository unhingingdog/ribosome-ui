type badge_variant = Neutral | Success | Warning | Error | Info

let badge_variant_of_string = function
  | "Neutral" -> Neutral
  | "Success" -> Success
  | "Warning" -> Warning
  | "Error" -> Error
  | "Info" -> Info
  | s -> failwith ("unknown badge variant: " ^ s)

let string_of_badge_variant = function
  | Neutral -> "Neutral"
  | Success -> "Success"
  | Warning -> "Warning"
  | Error -> "Error"
  | Info -> "Info"

type t = { id : string; label : string; variant : badge_variant }
