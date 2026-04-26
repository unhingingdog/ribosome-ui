open LexerTypes

type balancing_error =
  | NotClosable
  | Corrupted

(* Tokens that open a nesting level and require a matching closer *)
type opening_token =
  | OpenBrace
  | OpenBracket
  | OpenKey
  | OpenStringData

(* Tokens needed to close open structures. No sentinel None variant — use option at call sites. *)
type closing_token =
  | CloseBrace
  | CloseBracket
  | CloseKey
  | CloseStringData

(* Maps each opener to the closer that must balance it *)
let get_closing_token_for = function
  | OpenBrace      -> CloseBrace
  | OpenBracket    -> CloseBracket
  | OpenKey        -> CloseKey
  | OpenStringData -> CloseStringData

(* The character emitted when completing each closing token *)
let get_char_for = function
  | CloseBrace     -> '}'
  | CloseBracket   -> ']'
  | CloseKey       -> '"'
  | CloseStringData -> '"'

(* Tokens that pop a nesting level and trigger parent-state restoration *)
type pop_level_token =
  | PopCloseBrace
  | PopCloseBracket

(* Public error type *)
type char_error = CharError of json_parse_error

type error =
  | Char of char_error
  | NotClosable
  | Corrupted

(* The only place NotClosableInsideUnicode maps to NotClosable.
   All other json_parse_error variants map to Corrupted. *)
let error_of_parse_error = function
  | NotClosableInsideUnicode -> NotClosable
  | e                        -> Char (CharError e)

let error_of_balancing_error : balancing_error -> error = function
  | NotClosable -> NotClosable
  | Corrupted   -> Corrupted
