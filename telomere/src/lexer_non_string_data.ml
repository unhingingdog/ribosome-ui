open Lexer_types
open Lexer_non_string_check

(* Mirrors non_string_data.rs *)

let is_non_string_start (c : char) : bool =
  (c >= '0' && c <= '9') || c = '-' || c = 'n' || c = 't' || c = 'f'

(* Guard: true when a non-string value can start or continue here *)
let is_non_string_data (c : char) (state : json_state) : bool =
  match state with
  | Brace ExpectingValue | Bracket (Empty | ExpectingValue) ->
      is_non_string_start c
  | Brace (InValue (NonString _)) | Bracket (InValue (NonString _)) -> true
  | _ -> false

let continue_non_string (c : char) (buffer : string)
    (wrap : non_string_state -> json_state) :
    (token * json_state, json_parse_error) result =
  let status = check c buffer in
  let new_buf = buffer ^ String.make 1 c in
  let new_ns =
    match status with
    | Ok Complete -> Completable new_buf
    | _ -> NonCompletable new_buf
  in
  match status with
  | Ok _ -> Ok (NonStringData, wrap new_ns)
  | Error e -> Error e

let parse_non_string_data (c : char) (state : json_state) :
    (token * json_state, json_parse_error) result =
  match state with
  | Brace ExpectingValue ->
      let s = String.make 1 c in
      let ns = if c = '-' then NonCompletable s else Completable s in
      Ok (NonStringData, Brace (InValue (NonString ns)))
  | Bracket (Empty | ExpectingValue) ->
      let s = String.make 1 c in
      let ns = if c = '-' then NonCompletable s else Completable s in
      Ok (NonStringData, Bracket (InValue (NonString ns)))
  | Brace (InValue (NonString (Completable buffer | NonCompletable buffer))) ->
      continue_non_string c buffer (fun new_ns ->
          Brace (InValue (NonString new_ns)))
  | Bracket (InValue (NonString (Completable buffer | NonCompletable buffer)))
    ->
      continue_non_string c buffer (fun new_ns ->
          Bracket (InValue (NonString new_ns)))
  | _ -> Error UnexpectedCharInNonStringData
