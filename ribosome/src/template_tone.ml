type t = Default | Positive | Negative | Warning | Info

let of_string = function
  | "Default" -> Default
  | "Positive" -> Positive
  | "Negative" -> Negative
  | "Warning" -> Warning
  | "Info" -> Info
  | s -> failwith ("unknown tone: " ^ s)

let to_string = function
  | Default -> "Default"
  | Positive -> "Positive"
  | Negative -> "Negative"
  | Warning -> "Warning"
  | Info -> "Info"
