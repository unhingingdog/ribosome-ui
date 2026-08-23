type generation = { id : string; next_seq : int }

type t = {
  id : string;
  mode : Mode.t;
  tree : Template.t option;
  revision : int;
  generation : generation option;
  incremental : Incremental.state;
  recent_event_ids : string list;
}

let create ~id ~mode =
  Debug.log "session" (Printf.sprintf "create id=%s mode=%s" id mode.Mode.id);
  {
    id;
    mode;
    tree = None;
    revision = 0;
    generation = None;
    incremental = Incremental.create ();
    recent_event_ids = [];
  }

type event_result =
  | Updated of t
  | UserTurn of t * Template.t * Template_event.event

let max_event_window = 100

let add_event_id t event_id =
  let ids = event_id :: t.recent_event_ids in
  let ids =
    if Stdlib.List.length ids > max_event_window then
      Stdlib.List.rev (Stdlib.List.tl (Stdlib.List.rev ids))
    else ids
  in
  { t with recent_event_ids = ids }

let apply_event t ~event_id ~base_revision event : (event_result, string) result
    =
  if base_revision <> t.revision then begin
    Debug.log "session" (Printf.sprintf "apply_event REJECT stale event_id=%s expected_rev=%d got_rev=%d" event_id t.revision base_revision);
    Error
      ("stale revision: expected " ^ string_of_int t.revision ^ ", got "
      ^ string_of_int base_revision)
  end
  else if Stdlib.List.mem event_id t.recent_event_ids then begin
    Debug.log "session" (Printf.sprintf "apply_event REJECT duplicate event_id=%s" event_id);
    Error "duplicate event id"
  end
  else
    match t.tree with
    | None -> Error "no tree to apply event against"
    | Some tree -> (
        match Template_event.apply tree event with
        | Error e -> Error e
        | Ok (new_tree, _) -> (
            let t =
              { t with tree = Some new_tree; revision = t.revision + 1 }
            in
            let t = add_event_id t event_id in
            Debug.log "session" (Printf.sprintf "apply_event OK event_id=%s new_rev=%d" event_id t.revision);
            match event with
            | Change _ -> Ok (Updated t)
            | Click _ | Submit _ -> Ok (UserTurn (t, new_tree, event))))

let start_generation t ~gen_id =
  Debug.log "session" (Printf.sprintf "start_generation gen_id=%s session=%s" gen_id t.id);
  match t.generation with
  | Some gen when gen.id = gen_id ->
      Error "generation already active with this id"
  | Some _ -> Error "another generation is already active"
  | None ->
      let incremental = Incremental.create ?committed:t.tree () in
      let generation = Some { id = gen_id; next_seq = 0 } in
      Ok { t with incremental; generation }

let feed_delta t ~gen_id ~seq ~delta =
  match t.generation with
  | None -> Error "no active generation"
  | Some gen when gen.id <> gen_id -> Error "wrong generation"
  | Some gen when seq <> gen.next_seq ->
      Debug.log "session" (Printf.sprintf "feed_delta REJECT out-of-order gen=%s expected_seq=%d got_seq=%d" gen_id gen.next_seq seq);
      Error
        ("out of order sequence: expected " ^ string_of_int gen.next_seq
       ^ ", got " ^ string_of_int seq)
  | Some gen ->
      let incremental, update = Incremental.feed t.incremental delta in
      let gen = { gen with next_seq = gen.next_seq + 1 } in
      let t = { t with incremental; generation = Some gen } in
      let t =
        match update with
        | Incremental.Updated tree ->
            Debug.log "session" (Printf.sprintf "feed_delta updated gen=%s seq=%d new_rev=%d" gen_id seq (t.revision + 1));
            { t with tree = Some tree; revision = t.revision + 1 }
        | _ -> t
      in
      Ok (t, update)

let complete_generation t ~gen_id =
  Debug.log "session" (Printf.sprintf "complete_generation gen_id=%s session=%s" gen_id t.id);
  match t.generation with
  | None -> Error "no active generation"
  | Some gen when gen.id <> gen_id -> Error "wrong generation"
  | Some _ -> Ok { t with generation = None }

let fail_generation t ~gen_id =
  Debug.log "session" (Printf.sprintf "fail_generation gen_id=%s session=%s" gen_id t.id);
  match t.generation with
  | None -> Error "no active generation"
  | Some gen when gen.id <> gen_id -> Error "wrong generation"
  | Some _ -> Ok { t with generation = None }

let cancel_generation t ~gen_id =
  match t.generation with
  | None -> Error "no active generation"
  | Some gen when gen.id <> gen_id -> Error "wrong generation"
  | Some _ -> Ok { t with generation = None }
