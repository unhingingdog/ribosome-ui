open LexerTypes
open BalancerTypes

type balancer_state = {
  closing_stack: closing_token list;
  json_state: json_state;
  is_corrupted: bool;
}

let create () = {
  closing_stack = [];
  json_state = Pending;
  is_corrupted = false;
}

type stack_result =
  | Pushed  of closing_token list
  | Popped  of closing_token list
  | Ignored 
  | StackCorrupted

let modify_stack (stack : closing_token list) (token : token) : stack_result =
  match token with
  | OpenBrace -> Pushed (stack @ [CloseBrace])
  | OpenBracket -> Pushed (stack @ [CloseBracket])
  | OpenKey -> Pushed (stack @ [CloseKey])
  | OpenStringData -> Pushed (stack @ [CloseStringData])
  | CloseBrace | CloseBracket | CloseKey | CloseStringData -> begin
      let expected = match token with
        | CloseBrace -> CloseBrace
        | CloseBracket -> CloseBracket
        | CloseKey -> CloseKey
        | CloseStringData -> CloseStringData
        | _ -> assert false
      in
      match List.rev stack with
      | top :: rest when top = expected -> Popped (List.rev rest)
      | _ :: _ -> StackCorrupted
      | [] -> StackCorrupted
    end
  | StringContent | NonStringData | Comma | Colon | Whitespace -> Ignored

(* ------------------------------------------------------------------ *)
(* handle_pop_state_transition                                          *)
(* After a CloseBrace or CloseBracket, restore the parent state by     *)
(* inspecting the new top of the (already popped) stack.               *)
(* ------------------------------------------------------------------ *)

let is_pop_level_token (token : token) : bool =
  match token with
  | CloseBrace | CloseBracket -> true
  | _ -> false

let handle_pop_state_transition (stack : closing_token list) : json_state =
  (* Inspect the new top of the stack (last element = innermost remaining opener).
     List.nth_opt with a negative index throws Invalid_argument, so guard on empty. *)
  let len = List.length stack in
  if len = 0 then Pending
  else match List.nth_opt stack (len - 1) with
  | Some CloseBrace   -> Brace (InValue NestedValueComplete)
  | Some CloseBracket -> Bracket (InValue NestedValueComplete)
  | _                 -> Pending

(* ------------------------------------------------------------------ *)
(* get_balancing_chars                                                  *)
(* Mirrors get_balancing_chars.rs                                       *)
(* ------------------------------------------------------------------ *)

let get_balancing_chars (bs : balancer_state) : (string, balancing_error) result =
  if not (is_cleanly_closable bs.json_state) then
    Error NotClosable
  else
    let chars = List.rev_map get_char_for bs.closing_stack in
    Ok (String.concat "" (List.map (String.make 1) chars))

(* ------------------------------------------------------------------ *)
(* process_delta                                                        *)
(* Mirrors add_delta + get_completion in json_balancer.rs.             *)
(* Pure fold — threads balancer_state as a value.                      *)
(*                                                                      *)
(* Returns Ok (completion_chars, new_state) on success, or             *)
(* Error (error, new_state) on failure — the new_state is always       *)
(* returned so the caller can persist is_corrupted = true on hard      *)
(* errors (replacing the mutable field on the Rust struct).            *)
(* ------------------------------------------------------------------ *)

let step (bs : balancer_state) (c : char) :
    (balancer_state, error * balancer_state) result =
  match Lexer.parse_char c bs.json_state with
  | Error NotClosableInsideUnicode ->
    (* Soft error: do not corrupt the stream *)
    Error (NotClosable, bs)
  | Error e ->
    (* Hard error: poison the state *)
    Error (error_of_parse_error e, { bs with is_corrupted = true })
  | Ok (token, new_json_state) ->
    match modify_stack bs.closing_stack token with
    | StackCorrupted ->
      Error (Corrupted, { bs with is_corrupted = true })
    | Ignored ->
      Ok { bs with json_state = new_json_state }
    | Pushed new_stack ->
      Ok { closing_stack = new_stack; json_state = new_json_state; is_corrupted = false }
    | Popped new_stack ->
      let final_state =
        if is_pop_level_token token then
          handle_pop_state_transition new_stack
        else
          new_json_state
      in
      Ok { closing_stack = new_stack; json_state = final_state; is_corrupted = false }

let process_delta (bs : balancer_state) (delta : string) :
    (string * balancer_state, error * balancer_state) result =
  if bs.is_corrupted then
    Error (Corrupted, bs)
  else
    let result = String.fold_left (fun acc c ->
      match acc with
      | Error _ as e -> e
      | Ok state -> step state c
    ) (Ok bs) delta
    in
    match result with
    | Error _ as e -> e
    | Ok new_state ->
      match get_balancing_chars new_state with
      | Ok chars -> Ok (chars, new_state)
      | Error e  -> Error (error_of_balancing_error e, new_state)
