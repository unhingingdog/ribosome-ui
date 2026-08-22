(* Minimal JSON-RPC 2.0 framing. *)

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

val error_code_to_int : error_code -> int
val error_code_of_int : int -> error_code
val encode_id : id -> Yojson.Safe.t
val decode_id : Yojson.Safe.t -> (id, string) result
val encode_error : error -> Yojson.Safe.t
val encode_message : message -> Yojson.Safe.t
val decode_message : Yojson.Safe.t -> (message, string) result
val make_error_response : id -> error_code -> string -> message
val make_success_response : id -> Yojson.Safe.t -> message
val encode_to_line : message -> string
val decode_line : string -> (message, string) result
