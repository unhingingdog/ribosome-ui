open LexerTypes

(* Mirrors string_data.rs *)

(* Guard: true when currently inside an open or escaped string *)
let is_string_data (state : json_state) : bool =
  match state with
  | Brace (InKey (Open | Escaped))
  | Brace (InValue (String (Open | Escaped)))
  | Bracket (InValue (String (Open | Escaped))) ->
      true
  | _ -> false

(* Parse a character that is content inside a string literal *)
let parse_string_data (state : json_state) :
    (token * json_state, json_parse_error) result =
  match state with
  | Brace (InKey Open)
  | Brace (InValue (String Open))
  | Bracket (InValue (String Open)) ->
      ok_unchanged state StringContent
  | Brace (InKey Escaped) -> Ok (StringContent, Brace (InKey Open))
  | Brace (InValue (String Escaped)) ->
      Ok (StringContent, Brace (InValue (String Open)))
  | Bracket (InValue (String Escaped)) ->
      Ok (StringContent, Bracket (InValue (String Open)))
  | _ ->
      Error
        (TokenParseErrorMisc "Unexpected character outside of an open string")
