type json = Melange_json.t

type request_id =
  | Integer of int
  | String of string

type request = {
  id: request_id;
  method_: string;
  params: json option;
}

type error = {
  code: int;
  message: string;
  data: json option;
}

type response = {
  id: request_id option;
  result: (json, error) result;
}

type notification = {
  method_: string;
  params: json option;
}

type inbound =
  | Response of response
  | Notification of notification

let ( let* ) = Result.bind

let object_fields = function
  | `Assoc fields -> Ok fields
  | _ -> Error "expected JSON-RPC object"

let required name decoder fields =
  match Stdlib.List.assoc_opt name fields with
  | Some value -> decoder value
  | None -> Error ("missing JSON-RPC field: " ^ name)

let optional name fields =
  Ok (Stdlib.List.assoc_opt name fields)

let decode_string = function
  | `String value -> Ok value
  | _ -> Error "expected string"

let decode_int = function
  | `Int value -> Ok value
  | _ -> Error "expected integer"

let decode_version fields =
  match Stdlib.List.assoc_opt "jsonrpc" fields with
  | None -> Ok ()
  | Some (`String "2.0") -> Ok ()
  | _ -> Error "expected JSON-RPC version 2.0"

let decode_id = function
  | `Int value -> Ok (Integer value)
  | `String value -> Ok (String value)
  | _ -> Error "expected JSON-RPC id"

let decode_nullable_id = function
  | `Null -> Ok None
  | value -> Result.map Option.some (decode_id value)

let encode_id = function
  | Integer value -> `Int value
  | String value -> `String value

let encode_request (request : request) =
  let fields = [
    ("jsonrpc", `String "2.0");
    ("id", encode_id request.id);
    ("method", `String request.method_);
  ] in
  match request.params with
  | Some params -> `Assoc (fields @ [("params", params)])
  | None -> `Assoc fields

let decode_request json =
  let* fields = object_fields json in
  let* () = decode_version fields in
  let* id = required "id" decode_id fields in
  let* method_ = required "method" decode_string fields in
  let* params = optional "params" fields in
  Ok { id; method_; params }

let decode_error json =
  let* fields = object_fields json in
  let* code = required "code" decode_int fields in
  let* message = required "message" decode_string fields in
  let* data = optional "data" fields in
  Ok { code; message; data }

let decode_response fields =
  let* () = decode_version fields in
  let* id = required "id" decode_nullable_id fields in
  match Stdlib.List.assoc_opt "result" fields, Stdlib.List.assoc_opt "error" fields with
  | Some result, None -> Ok { id; result = Ok result }
  | None, Some error ->
    Result.map (fun error -> { id; result = Error error }) (decode_error error)
  | Some _, Some _ -> Error "JSON-RPC response has both result and error"
  | None, None -> Error "JSON-RPC response has neither result nor error"

let decode_notification fields =
  let* () = decode_version fields in
  let* method_ = required "method" decode_string fields in
  let* params = optional "params" fields in
  Ok { method_; params }

let decode_inbound json =
  let* fields = object_fields json in
  if Stdlib.List.mem_assoc "id" fields then
    Result.map (fun response -> Response response) (decode_response fields)
  else
    Result.map (fun notification -> Notification notification) (decode_notification fields)

let decode_string_inbound value =
  try decode_inbound (Melange_json.of_string value)
  with Melange_json.Of_string_error error -> Error error
