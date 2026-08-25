(* Shared WebSocket connection table.
   Maps session_id → Dream.websocket so broadcast callbacks can send
   directly via Lwt.async without a queue. Supports a "pending"
   WebSocket as fallback for messages sent before explicit session
   registration (e.g. user_turn delivered before Attach). *)

type t = {
  connections : (string, Dream.websocket) Hashtbl.t;
  mutable pending : Dream.websocket option;
}

let create () =
  { connections = Hashtbl.create 16; pending = None }

let register t ~session_id ws =
  Hashtbl.replace t.connections session_id ws;
  Debug.log "conn" (Printf.sprintf "register session=%s" session_id)

let unregister t ~session_id =
  Hashtbl.remove t.connections session_id;
  Debug.log "conn" (Printf.sprintf "unregister session=%s" session_id)

let set_pending t ws =
  t.pending <- Some ws;
  Debug.log "conn" "set pending websocket"

let clear_pending t =
  t.pending <- None;
  Debug.log "conn" "clear pending websocket"

let send t ~session_id msg =
  match Hashtbl.find_opt t.connections session_id with
  | Some ws -> Lwt.async (fun () -> Dream.send ws msg)
  | None -> begin
      match t.pending with
      | Some ws ->
          Debug.log "conn"
            (Printf.sprintf "send: using pending fallback for session=%s"
               session_id);
          Lwt.async (fun () -> Dream.send ws msg)
      | None ->
          Debug.log "conn"
            (Printf.sprintf "send: no connection for session=%s, dropping"
               session_id)
    end
