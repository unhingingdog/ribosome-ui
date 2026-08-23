(* Session registry.

   Keyed by Ribosome session ID with a secondary index from harness session
   ID. Stores UI and harness connection registrations separately. Mutation is
   behind a small runtime API. IDs and nonces are injectable in tests. *)

type conn_id = string
type ui_conn = { conn_id : conn_id; revision : int }
type harness_conn = { conn_id : conn_id }

type entry = {
  session_id : string;
  mode : string;
  harness_session_id : string;
  harness_nonce : string;
  ui_nonce : string;
  mutable ui_connections : ui_conn list;
  mutable harness_connection : harness_conn option;
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
  Debug.log "registry" (Printf.sprintf "start harness_session=%s" harness_session_id);
  match find_by_harness registry harness_session_id with
  | Some _ -> Error `Duplicate
  | None ->
      let session_id = id_gen.gen_session_id () in
      let ui_nonce = id_gen.gen_ui_nonce () in
      Debug.log "registry" (Printf.sprintf "start OK session_id=%s ui_nonce=%s" session_id ui_nonce);
      let entry =
        {
          session_id;
          mode;
          harness_session_id;
          harness_nonce;
          ui_nonce;
          ui_connections = [];
          harness_connection = None;
        }
      in
      Hashtbl.add registry.sessions session_id entry;
      Hashtbl.add registry.by_harness harness_session_id session_id;
      Ok entry

let attach_ui registry session_id ~conn_id ~revision =
  match find registry session_id with
  | None -> Error `NotFound
  | Some entry ->
      entry.ui_connections <- { conn_id; revision } :: entry.ui_connections;
      Debug.log "registry" (Printf.sprintf "attach_ui session=%s conn=%s rev=%d total_ui=%d" session_id conn_id revision (Stdlib.List.length entry.ui_connections));
      Ok ()

let detach_ui registry session_id ~conn_id =
  match find registry session_id with
  | None -> Error `NotFound
  | Some entry ->
      entry.ui_connections <-
        Stdlib.List.filter
          (fun (c : ui_conn) -> c.conn_id <> conn_id)
          entry.ui_connections;
      Ok ()

let attach_harness registry session_id ~conn_id =
  match find registry session_id with
  | None -> Error `NotFound
  | Some entry ->
      entry.harness_connection <- Some ({ conn_id } : harness_conn);
      Debug.log "registry" (Printf.sprintf "attach_harness session=%s conn=%s" session_id conn_id);
      Ok ()

let detach_harness registry session_id =
  match find registry session_id with
  | None -> Error `NotFound
  | Some entry ->
      entry.harness_connection <- None;
      Ok ()

let reconnect_ui registry session_id ~conn_id ~revision =
  match find registry session_id with
  | None -> Error `NotFound
  | Some entry ->
      let updated =
        Stdlib.List.map
          (fun (c : ui_conn) ->
            if c.conn_id = conn_id then { conn_id; revision } else c)
          entry.ui_connections
      in
      entry.ui_connections <- updated;
      Ok ()

let ui_connections registry session_id =
  match find registry session_id with
  | None -> []
  | Some entry -> entry.ui_connections

let harness_connection registry session_id =
  match find registry session_id with
  | None -> None
  | Some entry -> entry.harness_connection
