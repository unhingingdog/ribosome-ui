(* Vibecoded. I have no idea how this RPC works. *)

module type Transport = sig
  type t

  val send_line : t -> string -> unit
  val receive_line : t -> string option
  val close : t -> unit
end

type pending_request = {
  id: Codex_protocol.JsonRpc.request_id;
  method_: string;
}

type state = {
  next_id: int;
  pending: pending_request list;
}

type command =
  | Send_line of string

type correlated_response = {
  request: pending_request;
  result: (Codex_protocol.JsonRpc.json, Codex_protocol.JsonRpc.error) result;
}

type event =
  | Response of correlated_response
  | Notification of Codex_protocol.JsonRpc.notification
  | Unexpected_response of Codex_protocol.JsonRpc.request_id option
  | Protocol_error of string

let create () = {
  next_id = 1;
  pending = [];
}

let request state method_ params =
  let id = Codex_protocol.JsonRpc.Integer state.next_id in
  let pending_request = { id; method_ } in
  let json = Codex_protocol.JsonRpc.encode_request { id; method_; params } in
  let command = Send_line (Melange_json.to_string json) in
  pending_request, command, {
    next_id = state.next_id + 1;
    pending = state.pending @ [pending_request];
  }

let notification method_ params =
  let fields = [
    ("jsonrpc", `String "2.0");
    ("method", `String method_);
  ] in
  match params with
  | Some value -> Send_line (Melange_json.to_string (`Assoc (fields @ [("params", value)])))
  | None -> Send_line (Melange_json.to_string (`Assoc fields))

let rec take_pending id retained = function
  | [] -> None, Stdlib.List.rev retained
  | pending :: remaining when pending.id = id -> Some pending, Stdlib.List.rev_append retained remaining
  | pending :: remaining -> take_pending id (pending :: retained) remaining

let receive state line =
  match Codex_protocol.JsonRpc.decode_string_inbound line with
  | Error error -> Protocol_error error, state
  | Ok (Codex_protocol.JsonRpc.Notification notification) -> Notification notification, state
  | Ok (Codex_protocol.JsonRpc.Response response) ->
    (match response.id with
     | None -> Unexpected_response None, state
     | Some id ->
       match take_pending id [] state.pending with
       | None, _ -> Unexpected_response (Some id), state
       | Some request, pending -> Response { request; result = response.result }, { state with pending })
