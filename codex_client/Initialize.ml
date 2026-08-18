type client_info = {
  name: string;
  title: string option;
  version: string;
}

type capabilities = {
  experimental_api: bool;
  request_attestation: bool;
}

type server_info = {
  user_agent: string;
  codex_home: string;
  platform_family: string;
  platform_os: string;
}

type phase =
  | Not_started
  | Waiting of Codex_protocol.JsonRpc.request_id
  | Ready of server_info

type error =
  | Already_started
  | Unexpected_event
  | Server_error of Codex_protocol.JsonRpc.error
  | Invalid_response of string

let ( let* ) = Result.bind

let params client_info capabilities =
  `Assoc [
    ("clientInfo", `Assoc [
      ("name", `String client_info.name);
      ("title", match client_info.title with Some title -> `String title | None -> `Null);
      ("version", `String client_info.version);
    ]);
    ("capabilities", `Assoc [
      ("experimentalApi", `Bool capabilities.experimental_api);
      ("requestAttestation", `Bool capabilities.request_attestation);
    ]);
  ]

let start phase client client_info capabilities =
  match phase with
  | Not_started ->
    let request, command, client = Client.request client "initialize"
      (Some (params client_info capabilities)) in
    Ok (command, client, Waiting request.id)
  | Waiting _ | Ready _ -> Error Already_started

let required_string name fields =
  match Stdlib.List.assoc_opt name fields with
  | Some (`String value) -> Ok value
  | Some _ -> Error (Invalid_response ("expected string: " ^ name))
  | None -> Error (Invalid_response ("missing field: " ^ name))

let decode_server_info = function
  | `Assoc fields ->
    let* user_agent = required_string "userAgent" fields in
    let* codex_home = required_string "codexHome" fields in
    let* platform_family = required_string "platformFamily" fields in
    let* platform_os = required_string "platformOs" fields in
    Ok { user_agent; codex_home; platform_family; platform_os }
  | _ -> Error (Invalid_response "expected initialize response object")

let receive phase event =
  match phase, event with
  | Waiting id, Client.Response { request; result = Ok result }
    when request.id = id && request.method_ = "initialize" ->
    Result.map (fun server_info ->
      [Client.notification "initialized" None], Ready server_info
    ) (decode_server_info result)
  | Waiting id, Client.Response { request; result = Error error }
    when request.id = id && request.method_ = "initialize" -> Error (Server_error error)
  | Not_started, _ | Waiting _, _ | Ready _, _ -> Error Unexpected_event
