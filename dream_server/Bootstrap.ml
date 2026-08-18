open Lwt.Infix

type config = {
  interface: string;
  port: int;
  codex_command: Codex_client.Stdio.command;
  skill_root: string;
  cwd: string;
}

type ready = {
  process: Codex_client.Stdio.t;
  server_info: Codex_client.Initialize.server_info;
  skill: Codex_client.Skills.skill;
}

type error =
  | Process_closed
  | Process_write_failed
  | Initialize_failed
  | Skill_readiness_failed

let client_info = Codex_client.Initialize.{
  name = "ribosome-dream";
  title = Some "Ribosome Dream";
  version = "0.1.0";
}

let capabilities = Codex_client.Initialize.{
  experimental_api = false;
  request_attestation = false;
}

let send process command =
  match command with
  | Codex_client.Client.Send_line line ->
    Codex_client.Stdio.send_line process line >|= function
    | Ok () -> Ok ()
    | Error Codex_client.Stdio.Closed -> Error Process_write_failed

let rec await_initialize process client phase =
  Codex_client.Stdio.receive_line process >>= function
  | None -> Lwt.return (Error Process_closed)
  | Some line ->
    let event, client = Codex_client.Client.receive client line in
    match Codex_client.Initialize.receive phase event with
    | Ok (commands, Codex_client.Initialize.Ready server_info) ->
      Lwt_list.map_s (send process) commands >|= fun results ->
      if Stdlib.List.for_all Result.is_ok results then Ok (client, server_info)
      else Error Process_write_failed
    | Ok (_, (Codex_client.Initialize.Not_started | Codex_client.Initialize.Waiting _)) ->
      Lwt.return (Error Initialize_failed)
    | Error _ ->
      (match event with
       | Codex_client.Client.Notification _ -> await_initialize process client phase
       | Codex_client.Client.Response _
       | Codex_client.Client.Unexpected_response _
       | Codex_client.Client.Protocol_error _ -> Lwt.return (Error Initialize_failed))

let rec await_skill process client phase =
  Codex_client.Stdio.receive_line process >>= function
  | None -> Lwt.return (Error Process_closed)
  | Some line ->
    let event, client = Codex_client.Client.receive client line in
    match Codex_client.Skills.receive phase client event with
    | Ok (Codex_client.Skills.Skill_ready skill, client, Codex_client.Skills.Ready _) ->
      Lwt.return (Ok (client, skill))
    | Ok (Codex_client.Skills.Requested command, client, next_phase) ->
      send process command >>= (function
        | Ok () -> await_skill process client next_phase
        | Error error -> Lwt.return (Error error))
    | Ok _ -> Lwt.return (Error Skill_readiness_failed)
    | Error _ ->
      (match event with
       | Codex_client.Client.Notification _ -> await_skill process client phase
       | Codex_client.Client.Response _
       | Codex_client.Client.Unexpected_response _
       | Codex_client.Client.Protocol_error _ -> Lwt.return (Error Skill_readiness_failed))

let fail process error =
  Codex_client.Stdio.shutdown process >|= fun _ -> Error error

let start config =
  let process = Codex_client.Stdio.start config.codex_command in
  match Codex_client.Initialize.start Codex_client.Initialize.Not_started
    (Codex_client.Client.create ()) client_info capabilities with
  | Error _ -> fail process Initialize_failed
  | Ok (command, client, phase) ->
    send process command >>= (function
      | Error error -> fail process error
      | Ok () ->
        await_initialize process client phase >>= function
        | Error error -> fail process error
        | Ok (client, server_info) ->
          match Codex_client.Skills.start Codex_client.Skills.Not_started client config.skill_root config.cwd with
          | Error _ -> fail process Skill_readiness_failed
          | Ok (Codex_client.Skills.Requested command, client, phase) ->
            send process command >>= (function
              | Error error -> fail process error
              | Ok () ->
                await_skill process client phase >|= Result.map (fun (_, skill) -> { process; server_info; skill }))
          | Ok _ -> fail process Skill_readiness_failed)

let health_json = "{\"status\":\"ready\"}"

let health_handler _ = Dream.json health_json

let run config =
  Dream.run ~interface:config.interface ~port:config.port
    (Dream.router [Dream.get "/health" health_handler])
