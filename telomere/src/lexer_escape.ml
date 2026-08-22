open Lexer_types

(* Mirrors escape.rs *)

(* Called on '\': transitions String(Open) -> String(Escaped) *)
let handle_escape (state : json_state) :
    (token * json_state, json_parse_error) result =
  match state with
  | Brace (InKey Open) -> Ok (StringContent, Brace (InKey Escaped))
  | Brace (InValue (String Open)) ->
      Ok (StringContent, Brace (InValue (String Escaped)))
  | Bracket (InValue (String Open)) ->
      Ok (StringContent, Bracket (InValue (String Escaped)))
  | _ -> Error UnexpectedEscape

(* Called on the char following '\'.
   \u is a known limitation — not closable inside unicode escapes.
   All other standard escapes transition String(Escaped) -> String(Open). *)
let handle_escaped_char (c : char) (state : json_state) :
    (token * json_state, json_parse_error) result =
  if c = 'u' then Error NotClosableInsideUnicode
  else
    match state with
    | Brace (InKey Escaped) -> Ok (StringContent, Brace (InKey Open))
    | Brace (InValue (String Escaped)) ->
        Ok (StringContent, Brace (InValue (String Open)))
    | Bracket (InValue (String Escaped)) ->
        Ok (StringContent, Bracket (InValue (String Open)))
    | _ -> Error UnexpectedEscape
