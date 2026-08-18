type configuration = {
  cwd: string;
  model: string option;
}

type thread = {
  id: string;
}

type phase =
  | Idle
  | Waiting of {
      id: Codex_protocol.JsonRpc.request_id;
      method_: string;
    }
  | Active of thread

type error =
  | Already_active
  | Unexpected_event
  | Server_error of Codex_protocol.JsonRpc.error
  | Invalid_response of string

type outcome =
  | Requested of Client.command
  | Thread_ready of thread

let start_params configuration =
  let fields = [
    ("cwd", `String configuration.cwd);
    ("approvalPolicy", `String "never");
    ("sandbox", `String "read-only");
  ] in
  match configuration.model with
  | Some model -> `Assoc (("model", `String model) :: fields)
  | None -> `Assoc fields

let resume_params configuration thread_id =
  let fields = [
    ("threadId", `String thread_id);
    ("cwd", `String configuration.cwd);
    ("approvalPolicy", `String "never");
    ("sandbox", `String "read-only");
  ] in
  match configuration.model with
  | Some model -> `Assoc (("model", `String model) :: fields)
  | None -> `Assoc fields

let begin_request phase client method_ params =
  match phase with
  | Idle ->
    let request, command, client = Client.request client method_ (Some params) in
    Ok (Requested command, client, Waiting { id = request.id; method_ })
  | Waiting _ | Active _ -> Error Already_active

let start phase client configuration =
  begin_request phase client "thread/start" (start_params configuration)

let resume phase client configuration thread_id =
  begin_request phase client "thread/resume" (resume_params configuration thread_id)

let decode_thread = function
  | `Assoc fields ->
    (match Stdlib.List.assoc_opt "thread" fields with
     | Some (`Assoc thread_fields) ->
       (match Stdlib.List.assoc_opt "id" thread_fields with
        | Some (`String id) -> Ok { id }
        | Some _ -> Error (Invalid_response "expected string: thread.id")
        | None -> Error (Invalid_response "missing field: thread.id"))
     | Some _ -> Error (Invalid_response "expected object: thread")
     | None -> Error (Invalid_response "missing field: thread"))
  | _ -> Error (Invalid_response "expected thread response object")

let receive phase client event =
  match phase, event with
  | Waiting { id; method_ }, Client.Response { request; result = Ok result }
    when request.id = id && request.method_ = method_ ->
    Result.map (fun thread -> Thread_ready thread, client, Active thread) (decode_thread result)
  | Waiting { id; method_ }, Client.Response { request; result = Error error }
    when request.id = id && request.method_ = method_ -> Error (Server_error error)
  | Idle, _ | Waiting _, _ | Active _, _ -> Error Unexpected_event
