open Lwt.Infix

type error =
  | Process_closed
  | Process_write_failed
  | Thread_start_failed
  | Turn_start_failed
  | Session_transition_failed

let send ready command =
  Bootstrap.send ready.Bootstrap.process command >|= function
  | Ok () -> Ok ()
  | Error _ -> Error Process_write_failed

let rec await_thread ready phase =
  Codex_client.Stdio.receive_line ready.Bootstrap.process >>= function
  | None -> Lwt.return (Error Process_closed)
  | Some line ->
    let event, client = Codex_client.Client.receive ready.client line in
    match Codex_client.Thread.receive phase client event with
    | Ok (Codex_client.Thread.Thread_ready thread, client, Codex_client.Thread.Active _) ->
      Lwt.return (Ok ({ ready with Bootstrap.client }, thread))
    | Ok _ -> Lwt.return (Error Thread_start_failed)
    | Error _ ->
      (match event with
       | Codex_client.Client.Notification _ -> await_thread { ready with Bootstrap.client } phase
       | Codex_client.Client.Response _
       | Codex_client.Client.Unexpected_response _
       | Codex_client.Client.Protocol_error _ -> Lwt.return (Error Thread_start_failed))

let rec await_turn ready phase =
  Codex_client.Stdio.receive_line ready.Bootstrap.process >>= function
  | None -> Lwt.return (Error Process_closed)
  | Some line ->
    let event, client = Codex_client.Client.receive ready.client line in
    match Codex_client.Turn.receive phase client event with
    | Ok (Codex_client.Turn.Turn_started turn, client, Codex_client.Turn.Active _) ->
      Lwt.return (Ok ({ ready with Bootstrap.client }, turn))
    | Ok _ -> Lwt.return (Error Turn_start_failed)
    | Error _ ->
      (match event with
       | Codex_client.Client.Notification _ -> await_turn { ready with Bootstrap.client } phase
       | Codex_client.Client.Response _
       | Codex_client.Client.Unexpected_response _
       | Codex_client.Client.Protocol_error _ -> Lwt.return (Error Turn_start_failed))

let start_turn ready session thread =
  let request = Codex_client.Turn.{
    thread;
    skill = ready.Bootstrap.skill;
    semantic_input = session.Ribosome_session.Session.initial_prompt;
    tree = session.tree;
  } in
  match Codex_client.Turn.start Codex_client.Turn.Idle ready.client request with
  | Error _ -> Lwt.return (Error Turn_start_failed)
  | Ok (Codex_client.Turn.Requested command, client, phase) ->
    let ready = { ready with Bootstrap.client } in
    send ready command >>= (function
      | Error error -> Lwt.return (Error error)
      | Ok () ->
        await_turn ready phase >>= (function
          | Error error -> Lwt.return (Error error)
          | Ok (ready, turn) ->
            (match Ribosome_session.Session.start_generation session turn with
             | Ok session -> Lwt.return (Ok (ready, session))
             | Error _ -> Lwt.return (Error Session_transition_failed))))
  | Ok _ -> Lwt.return (Error Turn_start_failed)

let start ready session =
  let configuration = Codex_client.Thread.{ cwd = ready.Bootstrap.cwd; model = None } in
  match Codex_client.Thread.start Codex_client.Thread.Idle ready.client configuration with
  | Error _ -> Lwt.return (Error Thread_start_failed)
  | Ok (Codex_client.Thread.Requested command, client, phase) ->
    let ready = { ready with Bootstrap.client } in
    send ready command >>= (function
      | Error error -> Lwt.return (Error error)
      | Ok () ->
        await_thread ready phase >>= (function
          | Error error -> Lwt.return (Error error)
          | Ok (ready, thread) ->
            (match Ribosome_session.Session.attach_thread session thread with
             | Ok session -> start_turn ready session thread
             | Error _ -> Lwt.return (Error Session_transition_failed))))
  | Ok _ -> Lwt.return (Error Thread_start_failed)
