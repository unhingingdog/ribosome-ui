open Lexer_types
open Balancer_types

type balancer_state = {
  closing_stack : closing_token list;
  json_state : json_state;
  is_corrupted : bool;
}

let create () =
  { closing_stack = []; json_state = Pending; is_corrupted = false }

type stack_result =
  | Pushed of closing_token list
  | Popped of closing_token list
  | Ignored
  | StackCorrupted

let modify_stack (stack : closing_token list) (token : token) : stack_result =
  match token with
  | OpenBrace -> Pushed (CloseBrace :: stack)
  | OpenBracket -> Pushed (CloseBracket :: stack)
  | OpenKey -> Pushed (CloseKey :: stack)
  | OpenStringData -> Pushed (CloseStringData :: stack)
  | CloseBrace ->
      begin match stack with
      | CloseBrace :: rest -> Popped rest
      | _ -> StackCorrupted
      end
  | CloseBracket ->
      begin match stack with
      | CloseBracket :: rest -> Popped rest
      | _ -> StackCorrupted
      end
  | CloseKey ->
      begin match stack with
      | CloseKey :: rest -> Popped rest
      | _ -> StackCorrupted
      end
  | CloseStringData ->
      begin match stack with
      | CloseStringData :: rest -> Popped rest
      | _ -> StackCorrupted
      end
  | StringContent | NonStringData | Comma | Colon | Whitespace -> Ignored

let is_pop_level_token (token : token) : bool =
  match token with CloseBrace | CloseBracket -> true | _ -> false

(* After a CloseBrace or CloseBracket, restore the parent state by inspecting
   the new head of the (already popped) stack. *)
let handle_pop_state_transition stack =
  match stack with
  | CloseBrace :: _ -> Brace (InValue NestedValueComplete)
  | CloseBracket :: _ -> Bracket (InValue NestedValueComplete)
  | [] -> Pending
  | _ -> Pending

let get_balancing_chars bs : (string, balancing_error) result =
  if not (is_cleanly_closable bs.json_state) then Error NotClosable
  else
    let chars = List.map get_char_for bs.closing_stack in
    Ok (String.concat "" (List.map (String.make 1) chars))

let step (bs : balancer_state) (c : char) :
    (balancer_state, error * balancer_state) result =
  match Lexer.parse_char c bs.json_state with
  | Error NotClosableInsideUnicode -> Error (NotClosable, bs)
  | Error e -> Error (error_of_parse_error e, { bs with is_corrupted = true })
  | Ok (token, new_json_state) -> (
      match modify_stack bs.closing_stack token with
      | StackCorrupted -> Error (Corrupted, { bs with is_corrupted = true })
      | Ignored -> Ok { bs with json_state = new_json_state }
      | Pushed new_stack ->
          Ok
            {
              closing_stack = new_stack;
              json_state = new_json_state;
              is_corrupted = false;
            }
      | Popped new_stack ->
          let final_state =
            if is_pop_level_token token then
              handle_pop_state_transition new_stack
            else new_json_state
          in
          Ok
            {
              closing_stack = new_stack;
              json_state = final_state;
              is_corrupted = false;
            })

let process_delta bs delta =
  if bs.is_corrupted then Error (Corrupted, bs)
  else
    let result =
      String.fold_left
        (fun acc c ->
          match acc with Error _ as e -> e | Ok state -> step state c)
        (Ok bs) delta
    in
    match result with
    | Error _ as e -> e
    | Ok new_state -> (
        match get_balancing_chars new_state with
        | Ok chars -> Ok (chars, new_state)
        | Error e -> Error (error_of_balancing_error e, new_state))
