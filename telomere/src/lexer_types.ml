(* Token layer *)

type recursive_structure_type = Open | Close

type token =
  | OpenBrace
  | CloseBrace
  | OpenBracket
  | CloseBracket
  | OpenKey
  | CloseKey
  | OpenStringData
  | StringContent
  | CloseStringData
  | NonStringData
  | Comma
  | Colon
  | Whitespace

type json_parse_error =
  | QuoteCharAfterKeyClose
  | QuoteCharAfterValueClose
  | QuoteCharInNonStringData
  | UnexpectedQuoteChar
  | UnexpectedCharInNonStringData
  | UnexpectedEscape
  | UnexpectedComma
  | UnexpectedCharWhenExpectingValue
  | UnexpectedColon
  | UnexpectedOpenBracket
  | UnexpectedCloseBracket
  | UnexpectedOpenBrace
  | UnexpectedCloseBrace
  | InvalidCharEncountered
  | InvalidCharInNumber
  | InvalidCharInLiteral
  | InvalidNonStringDataFirstChar
  | NotClosableInsideUnicode
  | TokenParseErrorMisc of string

(* State machine types *)

type string_state = Open | Closed | Escaped

(* Buffer for in-progress numbers/literals.
   Immutable string — values are short (max ~20 chars) so per-char allocation is negligible. *)
type non_string_state =
  | Completable of string (* valid prefix; could legally end here *)
  | NonCompletable of string (* valid prefix; cannot legally end here yet *)

type prim_value =
  | String of string_state
  | NonString of non_string_state
  | NestedValueComplete (* a nested object/array was fully closed *)

type brace_state =
  | Empty (* '{' just opened *)
  | ExpectingKey (* after '{' or ',' *)
  | InKey of string_state (* currently reading a key *)
  | ExpectingValue (* after ':' *)
  | InValue of prim_value (* currently reading a value *)

type bracket_state =
  | Empty (* '[' just opened *)
  | ExpectingValue (* after '[' or ',' *)
  | InValue of prim_value (* currently reading a value *)

type json_state =
  | Brace of brace_state
  | Bracket of bracket_state
  | Pending (* before any input, or after whole document is closed *)

(* Shared helper used by all sub-parsers: return the current state unchanged *)
let ok_unchanged state token = Ok (token, state)

(* Whether the current state can be cleanly terminated without more input. *)
let is_cleanly_closable = function
  | Pending -> true
  | Brace Empty -> true
  | Brace (InValue (NonString (Completable _))) -> true
  | Brace (InValue (String Open)) -> true
  | Brace (InValue (String Closed)) -> true
  | Brace (InValue NestedValueComplete) -> true
  | Bracket Empty -> true
  | Bracket (InValue (NonString (Completable _))) -> true
  | Bracket (InValue (String Open)) -> true
  | Bracket (InValue (String Closed)) -> true
  | Bracket (InValue NestedValueComplete) -> true
  | _ -> false
