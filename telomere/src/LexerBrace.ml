open LexerTypes

(* Mirrors brace.rs *)

let parse_brace (kind : recursive_structure_type) (state : json_state) :
    (token * json_state, json_parse_error) result =
  match kind with
  | Open ->
      begin match state with
      | Pending | Brace ExpectingValue | Bracket (Empty | ExpectingValue) ->
          Ok (OpenBrace, Brace Empty)
      | _ -> Error UnexpectedOpenBrace
      end
  | Close ->
      begin match state with
      | Brace bs ->
          begin match bs with
          | Empty -> ok_unchanged state CloseBrace
          | InValue (String Closed)
          | InValue (NonString (Completable _))
          | InValue NestedValueComplete ->
              ok_unchanged state CloseBrace
          | _ -> Error UnexpectedCloseBrace
          end
      | _ -> Error UnexpectedCloseBrace
      end
