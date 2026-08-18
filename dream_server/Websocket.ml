open Lwt.Infix

type t = {
  registry: Dream_runtime.Runtime.registry ref;
  sockets: (string * Dream.websocket) list ref;
  mutable next_session_id: int;
  mutable next_connection_id: int;
}

type error =
  | Invalid_initial_message
  | Unknown_session
  | Session_transition_failed

type accepted = {
  session: Ribosome_session.Session.t;
  connection_id: string;
  message: Dream_protocol.ServerMessage.t;
}

let create () = {
  registry = ref Dream_runtime.Runtime.empty_registry;
  sockets = ref [];
  next_session_id = 1;
  next_connection_id = 1;
}

let replace_session state session =
  match Dream_runtime.Runtime.replace_session !(state.registry) session with
  | Ok registry -> state.registry := registry; Ok ()
  | Error _ -> Error Session_transition_failed

let connect state session =
  let connection_id = "connection-" ^ string_of_int state.next_connection_id in
  state.next_connection_id <- state.next_connection_id + 1;
  match Ribosome_session.Session.reconnect session connection_id with
  | Error _ -> Error Session_transition_failed
  | Ok (session, emission) ->
    (match replace_session state session with
     | Ok () -> Ok {
         session;
         connection_id;
         message = Dream_runtime.Runtime.server_message session emission;
       }
     | Error error -> Error error)

let negotiate state = function
  | Dream_protocol.ClientMessage.New_session { initial_prompt } ->
    let session_id = "session-" ^ string_of_int state.next_session_id in
    state.next_session_id <- state.next_session_id + 1;
    let session = Ribosome_session.Session.create ~initial_prompt session_id in
    (match Dream_runtime.Runtime.add_session !(state.registry) session with
     | Error _ -> Error Session_transition_failed
     | Ok registry ->
       state.registry := registry;
       connect state session)
  | Dream_protocol.ClientMessage.Resume_session { session_id } ->
    (match Dream_runtime.Runtime.find_session !(state.registry) session_id with
     | Some session -> connect state session
     | None -> Error Unknown_session)
  | Dream_protocol.ClientMessage.Component_event _
  | Dream_protocol.ClientMessage.Cancel _ -> Error Invalid_initial_message

let disconnect state session_id connection_id =
  match Dream_runtime.Runtime.find_session !(state.registry) session_id with
  | None -> ()
  | Some session ->
    match replace_session state (Ribosome_session.Session.disconnect session connection_id) with
    | Ok () -> ()
    | Error _ -> ()

let remove_socket state connection_id =
  state.sockets := Stdlib.List.filter (fun (id, _) -> id <> connection_id) !(state.sockets)

let rec drain state session_id connection_id websocket =
  Dream.receive websocket >>= function
  | Some _ -> drain state session_id connection_id websocket
  | None ->
    remove_socket state connection_id;
    disconnect state session_id connection_id;
    Lwt.return_unit

let handler state _ =
  Dream.websocket (fun websocket ->
    Dream.receive websocket >>= function
    | None -> Lwt.return_unit
    | Some line ->
      (match Dream_protocol.ClientMessage.decode_string line with
       | Error _ -> Dream.close_websocket ~code:1008 websocket
       | Ok message ->
         match negotiate state message with
         | Error _ -> Dream.close_websocket ~code:1008 websocket
         | Ok accepted ->
           state.sockets := (accepted.connection_id, websocket) :: !(state.sockets);
           Dream.send websocket (Dream_protocol.ServerMessage.encode_string accepted.message) >>= fun () ->
           drain state accepted.session.id accepted.connection_id websocket))

let route state = Dream.get "/v1/tui" (handler state)
