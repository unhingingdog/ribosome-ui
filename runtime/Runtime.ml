type registry = Ribosome_session.Session.t list

type registry_error =
  | Session_already_exists
  | Session_not_found

module type Client_port = sig
  type t

  val send : t -> string -> Dream_protocol.ServerMessage.t -> unit Lwt.t
end

let empty_registry = []

let find_session registry session_id =
  Stdlib.List.find_opt (fun session -> session.Ribosome_session.Session.id = session_id) registry

let add_session registry (session : Ribosome_session.Session.t) =
  match find_session registry session.id with
  | Some _ -> Error Session_already_exists
  | None -> Ok (registry @ [session])

let replace_session registry (session : Ribosome_session.Session.t) =
  if Stdlib.List.exists (fun existing -> existing.Ribosome_session.Session.id = session.id) registry then
    Ok (Stdlib.List.map (fun (existing : Ribosome_session.Session.t) ->
      if existing.id = session.id then session else existing
    ) registry)
  else Error Session_not_found

let interpret_codex_command process = function
  | Codex_client.Client.Send_line line -> Codex_client.Stdio.send_line process line

let server_message (session : Ribosome_session.Session.t) = function
  | Ribosome_session.Session.Session_state { revision; tree } ->
    Dream_protocol.ServerMessage.Session_state {
      session_id = session.id;
      revision;
      tree;
    }
  | Ribosome_session.Session.Template_updated { revision; tree } ->
    Dream_protocol.ServerMessage.Template_update {
      session_id = session.id;
      revision;
      tree;
    }

module Broadcast (Port : Client_port) = struct
  let emission port (session : Ribosome_session.Session.t) emission =
    let message = server_message session emission in
    Lwt_list.iter_s (fun connection_id -> Port.send port connection_id message) session.connections
end
