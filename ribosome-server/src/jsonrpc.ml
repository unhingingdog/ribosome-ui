(* Minimal JSON-RPC 2.0 framing.

   Implements request, response, notification, and error types plus
   newline-delimited stdio framing. Stdout contains protocol messages only;
   all logging goes to stderr. *)

type id = Int_id of int | String_id of string
type request = { id : id; method_ : string; params : Yojson.Safe.t option }
type notification = { method_ : string; params : Yojson.Safe.t option }

type error_code =
  | Parse_error
  | Invalid_request
  | Method_not_found
  | Invalid_params
  | Internal_error
  | Custom of int

type error = {
  code : error_code;
  message : string;
  data : Yojson.Safe.t option;
}

type message =
  | Request of request
  | Notification of notification
  | Success of { id : id; result : Yojson.Safe.t }
  | Error_response of { id : id; error : error }

let error_code_to_int = function
  | Parse_error -> -32700
  | Invalid_request -> -32600
  | Method_not_found -> -32601
  | Invalid_params -> -32602
  | Internal_error -> -32603
  | Custom n -> n

let error_code_of_int n =
  match n with
  | -32700 -> Parse_error
  | -32600 -> Invalid_request
  | -32601 -> Method_not_found
  | -32602 -> Invalid_params
  | -32603 -> Internal_error
  | _ -> Custom n

let encode_id id = match id with Int_id n -> `Int n | String_id s -> `String s

let decode_id json =
  match json with
  | `Int n -> Ok (Int_id n)
  | `String s -> Ok (String_id s)
  | _ -> Error "id must be integer or string"

let encode_error err : Yojson.Safe.t =
  `Assoc
    ([
       ("code", `Int (error_code_to_int err.code));
       ("message", `String err.message);
     ]
    @ match err.data with None -> [] | Some d -> [ ("data", d) ])

let encode_message msg : Yojson.Safe.t =
  match msg with
  | Request r ->
      `Assoc
        ([
           ("jsonrpc", `String "2.0");
           ("id", encode_id r.id);
           ("method", `String r.method_);
         ]
        @ match r.params with None -> [] | Some p -> [ ("params", p) ])
  | Notification n ->
      `Assoc
        ([ ("jsonrpc", `String "2.0"); ("method", `String n.method_) ]
        @ match n.params with None -> [] | Some p -> [ ("params", p) ])
  | Success { id; result } ->
      `Assoc
        [ ("jsonrpc", `String "2.0"); ("id", encode_id id); ("result", result) ]
  | Error_response { id; error } ->
      `Assoc
        [
          ("jsonrpc", `String "2.0");
          ("id", encode_id id);
          ("error", encode_error error);
        ]

let ( let* ) = Result.bind

let decode_message json : (message, string) result =
  let string_field name fields =
    match Stdlib.List.assoc_opt name fields with
    | Some (`String s) -> Ok s
    | _ -> Error ("expected string field: " ^ name)
  in
  match json with
  | `Assoc fields -> (
      let* _version =
        match Stdlib.List.assoc_opt "jsonrpc" fields with
        | Some (`String "2.0") -> Ok ()
        | _ -> Error "missing or invalid jsonrpc version"
      in
      let has_result = Stdlib.List.mem_assoc "result" fields in
      let has_error = Stdlib.List.mem_assoc "error" fields in
      if has_result && has_error then
        Error "message contains both result and error"
      else if has_result || has_error then
        let* id_json =
          match Stdlib.List.assoc_opt "id" fields with
          | Some v -> Ok v
          | None -> Error "missing id field"
        in
        let* id = decode_id id_json in
        if has_result then
          match Stdlib.List.assoc_opt "result" fields with
          | Some result -> Ok (Success { id; result })
          | None -> Error "impossible"
        else
          match Stdlib.List.assoc_opt "error" fields with
          | Some (`Assoc err_fields) ->
              let* code_int =
                match Stdlib.List.assoc_opt "code" err_fields with
                | Some (`Int n) -> Ok n
                | _ -> Error "error code must be integer"
              in
              let* message = string_field "message" err_fields in
              let data = Stdlib.List.assoc_opt "data" err_fields in
              Ok
                (Error_response
                   {
                     id;
                     error =
                       { code = error_code_of_int code_int; message; data };
                   })
          | _ -> Error "error field must be an object"
      else
        let* method_ = string_field "method" fields in
        let params = Stdlib.List.assoc_opt "params" fields in
        match Stdlib.List.assoc_opt "id" fields with
        | None -> Ok (Notification { method_; params })
        | Some id_json ->
            let* id = decode_id id_json in
            Ok (Request { id; method_; params }))
  | _ -> Error "expected object"

let make_error_response id code message =
  Error_response { id; error = { code; message; data = None } }

let make_success_response id result = Success { id; result }
let encode_to_line msg = Yojson.Safe.to_string (encode_message msg) ^ "\n"

let decode_line line : (message, string) result =
  match Yojson.Safe.from_string line with
  | json -> decode_message json
  | exception Yojson.Json_error msg -> Error ("json parse error: " ^ msg)
