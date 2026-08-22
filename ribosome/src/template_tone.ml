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

let decode json =
  Codec_decode.enum
    [
      ("Default", Default);
      ("Positive", Positive);
      ("Negative", Negative);
      ("Warning", Warning);
      ("Info", Info);
    ]
    json

let encode t = `String (to_string t)
