(* Shared WebSocket connection table.
   Maps session_id → Dream.websocket so broadcast callbacks can send
   directly via Lwt.async without a queue. *)

type t = (string, Dream.websocket) Hashtbl.t

let create () = Hashtbl.create 16

let register t ~session_id ws =
  Hashtbl.replace t session_id ws;
  Debug.log "conn" (Printf.sprintf "register session=%s" session_id)

let unregister t ~session_id =
  Hashtbl.remove t session_id;
  Debug.log "conn" (Printf.sprintf "unregister session=%s" session_id)

let send t ~session_id msg =
  match Hashtbl.find_opt t session_id with
  | None ->
      Debug.log "conn"
        (Printf.sprintf "send: no connection for session=%s, dropping"
           session_id)
  | Some ws -> Lwt.async (fun () -> Dream.send ws msg)
