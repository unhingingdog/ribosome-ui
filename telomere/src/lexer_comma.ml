open Lexer_types

(* Mirrors comma.rs *)

let parse_comma (state : json_state) :
    (token * json_state, json_parse_error) result =
  match state with
  | Brace (InValue (String Closed))
  | Brace (InValue (NonString (Completable _)))
  | Brace (InValue NestedValueComplete) ->
      Ok (Comma, Brace ExpectingKey)
  | Bracket (InValue (String Closed))
  | Bracket (InValue (NonString (Completable _)))
  | Bracket (InValue NestedValueComplete) ->
      Ok (Comma, Bracket ExpectingValue)
  | Brace (InKey Open)
  | Brace (InValue (String Open))
  | Bracket (InValue (String Open)) ->
      ok_unchanged state StringContent
  | Brace (InKey Escaped) -> Ok (StringContent, Brace (InKey Open))
  | Brace (InValue (String Escaped)) ->
      Ok (StringContent, Brace (InValue (String Open)))
  | Bracket (InValue (String Escaped)) ->
      Ok (StringContent, Bracket (InValue (String Open)))
  | _ -> Error UnexpectedComma
