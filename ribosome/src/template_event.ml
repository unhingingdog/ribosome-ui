type event =
  | Click of { target_id : string }
  | Change of { target_id : string; value : Template_input.input_value }
  | Submit of { target_id : string }

(* --- finding --- *)

let rec find_submittable tree target_id : Template_submittable.t option =
  if Template.id tree = target_id then
    match tree with Template.Submittable s -> Some s | _ -> None
  else
    match tree with
    | Template.Container c ->
        find_in_children find_submittable c.children target_id
    | Template.List l -> find_in_children find_submittable l.children target_id
    | _ -> None

and find_button tree target_id : Template_button.t option =
  match tree with
  | Template.Submittable s -> (
      match s.button with Some b when b.id = target_id -> Some b | _ -> None)
  | Template.Container c -> find_in_children find_button c.children target_id
  | Template.List l -> find_in_children find_button l.children target_id
  | _ -> None

and find_input tree target_id : Template_input.t option =
  match tree with
  | Template.Submittable s ->
      Stdlib.List.find_map
        (function
          | Template_submittable.FieldInput input when input.id = target_id ->
              Some input
          | _ -> None)
        s.value
  | Template.Container c -> find_in_children find_input c.children target_id
  | Template.List l -> find_in_children find_input l.children target_id
  | _ -> None

and find_select tree target_id : Template_select.t option =
  match tree with
  | Template.Submittable s ->
      Stdlib.List.find_map
        (function
          | Template_submittable.FieldSelect select when select.id = target_id
            ->
              Some select
          | _ -> None)
        s.value
  | Template.Container c -> find_in_children find_select c.children target_id
  | Template.List l -> find_in_children find_select l.children target_id
  | _ -> None

and find_in_children :
    'a.
    (Template.t -> string -> 'a option) ->
    Template.t list ->
    string ->
    'a option =
 fun finder children target_id ->
  Stdlib.List.find_map (fun child -> finder child target_id) children

(* --- updating --- *)

let rec update_input tree target_id new_value : Template.t option =
  match tree with
  | Template.Container c -> (
      match update_in_children c.children target_id new_value with
      | Some new_children ->
          Some (Template.Container { c with children = new_children })
      | None -> None)
  | Template.List l -> (
      match update_in_children l.children target_id new_value with
      | Some new_children ->
          Some (Template.List { l with children = new_children })
      | None -> None)
  | Template.Submittable s ->
      let rec update_fields = function
        | [] -> None
        | Template_submittable.FieldInput input :: rest ->
            if input.id = target_id then
              Some
                (Template_submittable.FieldInput
                   { input with value = Some new_value }
                :: rest)
            else
              update_fields rest
              |> Option.map (fun new_rest ->
                  Template_submittable.FieldInput input :: new_rest)
        | Template_submittable.FieldSelect select :: rest ->
            update_fields rest
            |> Option.map (fun new_rest ->
                Template_submittable.FieldSelect select :: new_rest)
      in
      update_fields s.value
      |> Option.map (fun new_value ->
          Template.Submittable { s with value = new_value })
  | _ -> None

and update_in_children children target_id new_value : Template.t list option =
  let rec loop acc = function
    | [] -> None
    | child :: rest -> (
        match update_input child target_id new_value with
        | Some new_child -> Some (Stdlib.List.rev acc @ (new_child :: rest))
        | None -> loop (child :: acc) rest)
  in
  loop [] children

let rec update_select tree target_id selected_value : Template.t option =
  match tree with
  | Template.Container c -> (
      match update_select_children c.children target_id selected_value with
      | Some new_children ->
          Some (Template.Container { c with children = new_children })
      | None -> None)
  | Template.List l -> (
      match update_select_children l.children target_id selected_value with
      | Some new_children ->
          Some (Template.List { l with children = new_children })
      | None -> None)
  | Template.Submittable s ->
      let rec update_fields = function
        | [] -> None
        | Template_submittable.FieldInput input :: rest ->
            update_fields rest
            |> Option.map (fun new_rest ->
                Template_submittable.FieldInput input :: new_rest)
        | Template_submittable.FieldSelect select :: rest ->
            if select.id = target_id then
              Some
                (Template_submittable.FieldSelect
                   { select with selected = Some selected_value }
                :: rest)
            else
              update_fields rest
              |> Option.map (fun new_rest ->
                  Template_submittable.FieldSelect select :: new_rest)
      in
      update_fields s.value
      |> Option.map (fun new_value ->
          Template.Submittable { s with value = new_value })
  | _ -> None

and update_select_children children target_id selected_value :
    Template.t list option =
  let rec loop acc = function
    | [] -> None
    | child :: rest -> (
        match update_select child target_id selected_value with
        | Some new_child -> Some (Stdlib.List.rev acc @ (new_child :: rest))
        | None -> loop (child :: acc) rest)
  in
  loop [] children

(* --- public apply --- *)

let apply tree event : (Template.t * event, string) result =
  match event with
  | Click { target_id } -> (
      match find_button tree target_id with
      | Some _ -> Ok (tree, event)
      | None -> Error ("click target not found or not a button: " ^ target_id))
  | Change { target_id; value } -> (
      match find_input tree target_id with
      | Some _ -> (
          match update_input tree target_id value with
          | Some new_tree -> Ok (new_tree, event)
          | None -> Error ("change target not found: " ^ target_id))
      | None -> (
          match find_select tree target_id with
          | Some _ -> (
              match value with
              | Template_input.String str -> (
                  match update_select tree target_id str with
                  | Some new_tree -> Ok (new_tree, event)
                  | None -> Error ("change target not found: " ^ target_id))
              | Int _ -> Error "change value for select must be a string")
          | None ->
              Error
                ("change target not found or not an input/select: " ^ target_id)
          ))
  | Submit { target_id } -> (
      match find_submittable tree target_id with
      | Some _ -> Ok (tree, event)
      | None ->
          Error ("submit target not found or not a submittable: " ^ target_id))
