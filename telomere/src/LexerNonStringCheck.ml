open LexerTypes

(* Mirrors is_valid_non_string_data.rs *)

type completion_check = Complete | Incomplete

let literals = [ "true"; "false"; "null" ]

(* Check an incomplete number suffix that float_of_string_opt rejected.
   Handles the valid intermediate forms: "1e", "1E", "1e+", "1e-" etc. *)
let check_incomplete_number_suffix (new_value : string) :
    (completion_check, json_parse_error) result =
  let len = String.length new_value in
  let last = new_value.[len - 1] in
  let prefix = String.sub new_value 0 (len - 1) in
  let has_exp = String.contains prefix 'e' || String.contains prefix 'E' in
  if
    (last = 'e' || last = 'E')
    && (not has_exp)
    && float_of_string_opt prefix <> None
  then Ok Incomplete
  else if
    (last = '+' || last = '-')
    && String.length prefix > 0
    && (prefix.[String.length prefix - 1] = 'e'
       || prefix.[String.length prefix - 1] = 'E')
  then begin
    let num_part = String.sub prefix 0 (String.length prefix - 1) in
    if float_of_string_opt num_part <> None then Ok Incomplete
    else Error InvalidCharInNumber
  end
  else Error InvalidCharInNumber

(* Check whether (buffer ^ c) is a complete, incomplete, or invalid
   non-string (number / literal) value. Called before appending c. *)
let check (c : char) (buffer : string) :
    (completion_check, json_parse_error) result =
  let new_value = buffer ^ String.make 1 c in
  let first_char =
    if String.length new_value > 0 then new_value.[0] else '\x00'
  in
  if first_char = 't' || first_char = 'f' || first_char = 'n' then
    begin if List.mem new_value literals then Ok Complete
    else if
      List.exists (fun lit -> String.starts_with ~prefix:new_value lit) literals
    then Ok Incomplete
    else Error InvalidCharInLiteral
    end
  else if (first_char >= '0' && first_char <= '9') || first_char = '-' then
    begin if new_value = "-" then Ok Incomplete
    else
      match float_of_string_opt new_value with
      | Some _ ->
          let last = new_value.[String.length new_value - 1] in
          if last = '.' then Ok Incomplete else Ok Complete
      | None -> check_incomplete_number_suffix new_value
    end
  else Error InvalidNonStringDataFirstChar
