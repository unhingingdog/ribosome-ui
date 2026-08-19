open Lwt.Infix

type t = {
  registry: Dream_runtime.Runtime.registry ref;
  sockets: (string * Dream.websocket) list ref;
  ready: Bootstrap.ready option ref;
  mutable pump_running: bool;
  mutable next_session_id: int;
  mutable next_connection_id: int;
}

type error =
  | Invalid_initial_message
  | Unknown_session
  | Session_transition_failed

type dispatch =
  | Event_accepted of Ribosome_session.Session.accepted_event
  | Cancellation_requested of Codex_client.Turn.turn

type dispatch_error =
  | Event_rejected of {
      session_id: string;
      event_id: string;
      reason: string;
    }
  | Cancellation_rejected

type accepted = {
  session: Ribosome_session.Session.t;
  connection_id: string;
  message: Dream_protocol.ServerMessage.t;
}

let create ?ready () = {
  registry = ref Dream_runtime.Runtime.empty_registry;
  sockets = ref [];
  ready = ref ready;
  pump_running = false;
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

module Port = struct
  type nonrec t = t

  let send state connection_id message =
    match Stdlib.List.assoc_opt connection_id !(state.sockets) with
    | Some websocket -> Dream.send websocket (Dream_protocol.ServerMessage.encode_string message)
    | None -> Lwt.return_unit
end

module Broadcast = Dream_runtime.Runtime.Broadcast (Port)

let broadcast state session emission = Broadcast.emission state session emission

let start_initial_turn state session_id =
  match !(state.ready), Dream_runtime.Runtime.find_session !(state.registry) session_id with
  | None, _ | _, None -> Lwt.return (Error Session_transition_failed)
  | Some ready, Some session ->
    FirstTurn.start ready session >|= function
    | Error _ -> Error Session_transition_failed
    | Ok (ready, session) ->
      state.ready := Some ready;
      (match replace_session state session, session.generation with
       | Ok (), Some { turn; _ } ->
         Ok (session, Dream_protocol.ServerMessage.Generation_started {
           session_id = session.id;
           turn_id = turn.id;
         })
       | Error _, _ | Ok (), None -> Error Session_transition_failed)

let active_generation session =
  match session.Ribosome_session.Session.thread, session.generation with
  | Some thread, Some { turn; _ } -> Some (thread, turn)
  | None, _ | Some _, None -> None

let send_to_session state (session : Ribosome_session.Session.t) message =
  Lwt_list.iter_s (fun connection_id -> Port.send state connection_id message) session.connections

let finish_generation state session turn_id message =
  let transition = match message with
    | Dream_protocol.ServerMessage.Generation_completed _ ->
      Ribosome_session.Session.complete_generation session turn_id
    | Dream_protocol.ServerMessage.Generation_failed _ ->
      Ribosome_session.Session.fail_generation session turn_id
    | Dream_protocol.ServerMessage.Session_state _
    | Dream_protocol.ServerMessage.Template_update _
    | Dream_protocol.ServerMessage.Generation_started _
    | Dream_protocol.ServerMessage.Event_rejected _ -> Error Ribosome_session.Session.Wrong_turn
  in
  match transition with
  | Error _ -> Lwt.return_unit
  | Ok session ->
    (match replace_session state session with
     | Ok () -> send_to_session state session message
     | Error _ -> Lwt.return_unit)

let handle_generation_event state event =
  match event with
  | Codex_client.Client.Notification _ ->
    let active_sessions = Stdlib.List.filter_map (fun session ->
      match active_generation session with
      | Some generation -> Some (session, generation)
      | None -> None
    ) !(state.registry) in
    let rec route = function
      | [] -> Lwt.return_unit
      | (session, (thread, turn)) :: remaining ->
        match Codex_client.Generation.route thread turn event with
        | Ok Codex_client.Generation.Ignored -> route remaining
        | Error _ ->
          finish_generation state session turn.id
            (Dream_protocol.ServerMessage.Generation_failed {
              session_id = session.id;
              turn_id = turn.id;
              message = "invalid Codex generation notification";
            })
        | Ok (Codex_client.Generation.Routed (Codex_client.Generation.Delta { delta; _ })) ->
          (match Ribosome_session.Session.feed_delta session delta with
           | Error _ -> Lwt.return_unit
           | Ok (session, None) ->
             (match replace_session state session with Ok () -> Lwt.return_unit | Error _ -> Lwt.return_unit)
           | Ok (session, Some emission) ->
             (match replace_session state session with
              | Ok () -> broadcast state session emission
              | Error _ -> Lwt.return_unit))
        | Ok (Codex_client.Generation.Routed (Codex_client.Generation.Turn_finished completion)) ->
          let message = match completion with
            | Codex_client.Generation.Completed
            | Codex_client.Generation.Interrupted -> Dream_protocol.ServerMessage.Generation_completed {
                session_id = session.id;
                turn_id = turn.id;
              }
            | Codex_client.Generation.Failed message -> Dream_protocol.ServerMessage.Generation_failed {
                session_id = session.id;
                turn_id = turn.id;
                message;
              }
          in
          finish_generation state session turn.id message
    in
    route active_sessions
  | Codex_client.Client.Response _
  | Codex_client.Client.Unexpected_response _
  | Codex_client.Client.Protocol_error _ -> Lwt.return_unit

let pump_once state =
  match !(state.ready) with
  | None -> Lwt.return_unit
  | Some ready ->
    Codex_client.Stdio.receive_line ready.process >>= function
    | None ->
      state.pump_running <- false;
      Lwt.return_unit
    | Some line ->
      let event, client = Codex_client.Client.receive ready.client line in
      state.ready := Some { ready with Bootstrap.client };
      handle_generation_event state event

let rec pump state =
  if state.pump_running then
    pump_once state >>= fun () -> pump state
  else Lwt.return_unit

let start_pump state =
  if not state.pump_running then begin
    state.pump_running <- true;
    Lwt.async (fun () -> pump state)
  end

let event_reason = function
  | Ribosome_session.Session.Not_component_event -> "not a component event"
  | Ribosome_session.Session.Wrong_session -> "wrong session"
  | Ribosome_session.Session.Stale_revision -> "stale revision"
  | Ribosome_session.Session.No_template -> "no template"
  | Ribosome_session.Session.Unknown_component _ -> "unknown component"
  | Ribosome_session.Session.Invalid_component_event -> "invalid component event"
  | Ribosome_session.Session.Duplicate_event_id -> "duplicate event ID"

let dispatch state = function
  | Dream_protocol.ClientMessage.Component_event ({ session_id; event_id; _ } as message) ->
    (match Dream_runtime.Runtime.find_session !(state.registry) session_id with
     | None -> Error (Event_rejected { session_id; event_id; reason = "unknown session" })
     | Some session ->
       (match Ribosome_session.Session.reduce_event session
         (Dream_protocol.ClientMessage.Component_event message) with
        | Error error -> Error (Event_rejected { session_id; event_id; reason = event_reason error })
        | Ok (session, event) ->
          (match replace_session state session with
           | Ok () -> Ok (Event_accepted event)
           | Error _ -> Error (Event_rejected { session_id; event_id; reason = "session transition failed" }))))
  | Dream_protocol.ClientMessage.Cancel { session_id } ->
    (match Dream_runtime.Runtime.find_session !(state.registry) session_id with
     | None -> Error Cancellation_rejected
     | Some session ->
       (match Ribosome_session.Session.request_cancellation session with
        | Error _ -> Error Cancellation_rejected
        | Ok (session, turn) ->
          (match replace_session state session with
           | Ok () -> Ok (Cancellation_requested turn)
           | Error _ -> Error Cancellation_rejected)))
  | Dream_protocol.ClientMessage.New_session _
  | Dream_protocol.ClientMessage.Resume_session _ -> Error Cancellation_rejected

let rec drain state session_id connection_id websocket =
  Dream.receive websocket >>= function
  | Some line ->
    (match Dream_protocol.ClientMessage.decode_string line with
     | Error _ -> Dream.close_websocket ~code:1008 websocket
     | Ok message ->
       (match dispatch state message with
        | Ok (Event_accepted _ | Cancellation_requested _) -> drain state session_id connection_id websocket
        | Error (Event_rejected rejection) ->
          Dream.send websocket (Dream_protocol.ServerMessage.encode_string
            (Dream_protocol.ServerMessage.Event_rejected {
              session_id = rejection.session_id;
              event_id = rejection.event_id;
              reason = rejection.reason;
            })) >>= fun () ->
          drain state session_id connection_id websocket
        | Error Cancellation_rejected -> Dream.close_websocket ~code:1008 websocket))
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
           (match message, !(state.ready) with
            | Dream_protocol.ClientMessage.New_session _, Some _ ->
              start_initial_turn state accepted.session.id >>= (function
                | Ok (_, generation_started) ->
                  Dream.send websocket (Dream_protocol.ServerMessage.encode_string generation_started)
                | Error _ -> Dream.close_websocket ~code:1011 websocket) >>= fun () ->
              start_pump state;
              drain state accepted.session.id accepted.connection_id websocket
            | Dream_protocol.ClientMessage.New_session _, None
            | Dream_protocol.ClientMessage.Resume_session _, _ ->
              drain state accepted.session.id accepted.connection_id websocket
            | Dream_protocol.ClientMessage.Component_event _, _
            | Dream_protocol.ClientMessage.Cancel _, _ -> Dream.close_websocket ~code:1008 websocket)))

let route state = Dream.get "/v1/tui" (handler state)
