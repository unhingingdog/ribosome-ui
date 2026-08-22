open Lexer_types

(* Mirrors bracket.rs *)

let parse_bracket (kind : recursive_structure_type) (state : json_state) :
    (token * json_state, json_parse_error) result =
  match kind with
  | Open ->
      begin match state with
      | Pending | Brace ExpectingValue | Bracket (Empty | ExpectingValue) ->
          Ok (OpenBracket, Bracket Empty)
      | _ -> Error UnexpectedOpenBracket
      end
  | Close ->
      begin match state with
      | Bracket bs ->
          begin match bs with
          | Empty -> ok_unchanged state CloseBracket
          | InValue (String Closed)
          | InValue (NonString (Completable _))
          | InValue NestedValueComplete ->
              ok_unchanged state CloseBracket
          | _ -> Error UnexpectedCloseBracket
          end
      | _ -> Error UnexpectedCloseBracket
      end
