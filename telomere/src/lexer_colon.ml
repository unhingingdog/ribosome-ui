open Lexer_types

let parse_colon (state : json_state) :
    (token * json_state, json_parse_error) result =
  match state with
  | Brace bs ->
      begin match bs with
      | InKey Closed -> Ok (Colon, Brace ExpectingValue)
      | InKey Open | InValue (String Open) -> ok_unchanged state StringContent
      | InKey Escaped -> Ok (StringContent, Brace (InKey Open))
      | InValue (String Escaped) ->
          Ok (StringContent, Brace (InValue (String Open)))
      | _ -> Error UnexpectedColon
      end
  | Bracket bs ->
      begin match bs with
      | InValue (String Open) -> ok_unchanged state StringContent
      | InValue (String Escaped) ->
          Ok (StringContent, Bracket (InValue (String Open)))
      | _ -> Error UnexpectedColon
      end
  | _ -> Error UnexpectedColon
