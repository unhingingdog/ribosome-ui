open LexerTypes

(* Mirrors quote.rs *)

let parse_quote_char (state : json_state) :
    (token * json_state, json_parse_error) result =
  match state with
  | Brace (Empty | ExpectingKey) ->
    Ok (OpenKey, Brace (InKey Open))
  | Brace ExpectingValue ->
    Ok (OpenStringData, Brace (InValue (String Open)))
  | Bracket (Empty | ExpectingValue) ->
    Ok (OpenStringData, Bracket (InValue (String Open)))
  | Brace (InKey Open) ->
    Ok (CloseKey, Brace (InKey Closed))
  | Brace (InKey Escaped) ->
    Ok (StringContent, Brace (InKey Open))
  | Brace (InKey Closed) ->
    Error QuoteCharAfterKeyClose
  | Brace (InValue (String Open)) ->
    Ok (CloseStringData, Brace (InValue (String Closed)))
  | Brace (InValue (String Escaped)) ->
    Ok (StringContent, Brace (InValue (String Open)))
  | Brace (InValue (String Closed)) ->
    Error QuoteCharAfterValueClose
  | Bracket (InValue (String Open)) ->
    Ok (CloseStringData, Bracket (InValue (String Closed)))
  | Bracket (InValue (String Escaped)) ->
    Ok (StringContent, Bracket (InValue (String Open)))
  | Bracket (InValue (String Closed)) ->
    Error QuoteCharAfterValueClose
  | Brace (InValue (NonString _ | NestedValueComplete))
  | Bracket (InValue (NonString _ | NestedValueComplete)) ->
    Error QuoteCharInNonStringData
  | Pending -> Error UnexpectedQuoteChar
