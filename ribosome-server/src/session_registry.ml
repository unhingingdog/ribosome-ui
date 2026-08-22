(* Minimal session registry.

   Keyed by Ribosome session ID with a secondary index from harness session
   ID. Supports create, find, and duplicate detection. Connection tracking,
   attach/detach, and reconnect are added in Task 5.6. *)

type entry = {
  session_id : string;
  mode : string;
  harness_session_id : string;
  harness_nonce : string;
  ui_nonce : string;
}

type t = {
  sessions : (string, entry) Hashtbl.t;
  by_harness : (string, string) Hashtbl.t;
}

type id_gen = { gen_session_id : unit -> string; gen_ui_nonce : unit -> string }

let create () = { sessions = Hashtbl.create 16; by_harness = Hashtbl.create 16 }
let find registry session_id = Hashtbl.find_opt registry.sessions session_id

let find_by_harness registry harness_session_id =
  match Hashtbl.find_opt registry.by_harness harness_session_id with
  | Some sid -> Hashtbl.find_opt registry.sessions sid
  | None -> None

let start ?(mode = "ui") ~(id_gen : id_gen) ~(registry : t)
    ~(harness_session_id : string) ~(harness_nonce : string) () =
  match find_by_harness registry harness_session_id with
  | Some _ -> Error `Duplicate
  | None ->
      let session_id = id_gen.gen_session_id () in
      let ui_nonce = id_gen.gen_ui_nonce () in
      let entry =
        { session_id; mode; harness_session_id; harness_nonce; ui_nonce }
      in
      Hashtbl.add registry.sessions session_id entry;
      Hashtbl.add registry.by_harness harness_session_id session_id;
      Ok entry
