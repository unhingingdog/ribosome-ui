type generation = { id : string; next_seq : int }

type t = {
  id : string;
  mode : Mode.t;
  tree : Template.t option;
  revision : int;
  generation : generation option;
  incremental : Incremental.state;
}

let create ~id ~mode =
  {
    id;
    mode;
    tree = None;
    revision = 0;
    generation = None;
    incremental = Incremental.create ();
  }

let start_generation t ~gen_id =
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
            { t with tree = Some tree; revision = t.revision + 1 }
        | _ -> t
      in
      Ok (t, update)

let complete_generation t ~gen_id =
  match t.generation with
  | None -> Error "no active generation"
  | Some gen when gen.id <> gen_id -> Error "wrong generation"
  | Some _ -> Ok { t with generation = None }

let fail_generation t ~gen_id =
  match t.generation with
  | None -> Error "no active generation"
  | Some gen when gen.id <> gen_id -> Error "wrong generation"
  | Some _ -> Ok { t with generation = None }

let cancel_generation t ~gen_id =
  match t.generation with
  | None -> Error "no active generation"
  | Some gen when gen.id <> gen_id -> Error "wrong generation"
  | Some _ -> Ok { t with generation = None }
