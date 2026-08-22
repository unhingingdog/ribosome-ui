open Lexer_types

type balancing_error = NotClosable | Corrupted

(* Tokens needed to close open structures. *)
type closing_token = CloseBrace | CloseBracket | CloseKey | CloseStringData

(* The character emitted when completing each closing token. *)
let get_char_for = function
  | CloseBrace -> '}'
  | CloseBracket -> ']'
  | CloseKey -> '"'
  | CloseStringData -> '"'

(* Public error type *)
type char_error = CharError of json_parse_error
type error = Char of char_error | NotClosable | Corrupted

(* The only place NotClosableInsideUnicode maps to NotClosable.
   All other json_parse_error variants map to Corrupted. *)
let error_of_parse_error = function
  | NotClosableInsideUnicode -> NotClosable
  | e -> Char (CharError e)

let error_of_balancing_error : balancing_error -> error = function
  | NotClosable -> NotClosable
  | Corrupted -> Corrupted
