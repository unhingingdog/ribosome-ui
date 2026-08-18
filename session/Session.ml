type lifecycle =
  | Starting
  | Ready
  | Closed

type t = {
  id: string;
  thread: Codex_client.Thread.thread option;
  tree: Ribosome_core.Types.template option;
  revision: int;
  connections: string list;
  lifecycle: lifecycle;
}

type error =
  | Thread_already_attached
  | Session_closed

let create id = {
  id;
  thread = None;
  tree = None;
  revision = 0;
  connections = [];
  lifecycle = Starting;
}

let attach_thread session thread =
  match session.lifecycle, session.thread with
  | Closed, _ -> Error Session_closed
  | Starting, None -> Ok { session with thread = Some thread; lifecycle = Ready }
  | Starting, Some _ | Ready, _ -> Error Thread_already_attached

let connect session connection_id =
  match session.lifecycle with
  | Closed -> Error Session_closed
  | Starting | Ready ->
    let connections = if Stdlib.List.mem connection_id session.connections then session.connections
      else session.connections @ [connection_id]
    in
    Ok { session with connections }

let disconnect session connection_id = {
  session with connections = Stdlib.List.filter (fun id -> id <> connection_id) session.connections;
}

let close session = { session with lifecycle = Closed; connections = [] }
