open LexerTypes
open LexerEscape
open LexerBrace
open LexerBracket
open LexerColon
open LexerComma
open LexerQuote
open LexerStringData
open LexerNonStringData

(* Mirrors dispatcher.rs — priority-ordered routing to sub-parsers.
   Pure function: takes a char and current state, returns (token * new_state) or error. *)

let is_escaped (state : json_state) : bool =
  match state with
  | Brace (InKey Escaped)
  | Brace (InValue (String Escaped))
  | Bracket (InValue (String Escaped)) -> true
  | _ -> false

let is_completable (state : json_state) : bool =
  match state with
  | Brace (InValue (String Closed))
  | Brace (InValue (NonString (Completable _)))
  | Brace (InValue NestedValueComplete)
  | Bracket (InValue (String Closed))
  | Bracket (InValue (NonString (Completable _)))
  | Bracket (InValue NestedValueComplete) -> true
  | _ -> false

(* Priorities 3-5: shared fallthrough used by both the normal path and
   the completable path when the char is not a delimiter. *)
let parse_lower_priorities (c : char) (state : json_state) :
    (token * json_state, json_parse_error) result =
  (* Priority 3: string data — structural chars are transparent inside open strings *)
  if is_string_data state then
    parse_string_data state
  (* Priority 4: non-string data — numbers, booleans, null *)
  else if is_non_string_data c state then
    parse_non_string_data c state
  (* Priority 5: remaining structural tokens, whitespace, error fallthrough *)
  else
    match c with
    | '{' -> parse_brace Open state
    | '}' -> parse_brace Close state
    | '[' -> parse_bracket Open state
    | ']' -> parse_bracket Close state
    | ':' -> parse_colon state
    | ',' -> parse_comma state
    | ' ' | '\t' | '\n' | '\r' -> Ok (Whitespace, state)
    | _   -> Error InvalidCharEncountered

let parse_char (c : char) (state : json_state) :
    (token * json_state, json_parse_error) result =
  (* Priority 0: resolve escaped char before anything else.
     Prevents backslash-quote from closing the string. *)
  if is_escaped state then
    handle_escaped_char c state
  else
    match c with
    (* Priority 1: string controls always win when inside strings *)
    | '\\' -> handle_escape state
    | '"'  -> parse_quote_char state
    | _ ->
      (* Priority 2: delimiters must preempt non-string parsing when in a completable
         state — prevents `,`, `}`, `]` from being swallowed by the non-string accumulator *)
      if is_completable state then
        match c with
        | ',' -> parse_comma state
        | '}' -> parse_brace Close state
        | ']' -> parse_bracket Close state
        | _   -> parse_lower_priorities c state
      else
        parse_lower_priorities c state
