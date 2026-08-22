(* Versioned harness stream protocol. *)

val version : string

type session_id = string

type attach = {
  session_id : session_id;
  harness_session_id : string;
  nonce : string;
}

type delta = {
  session_id : session_id;
  generation_id : string;
  seq : int;
  content : string;
}

type generation_completed = { session_id : session_id; generation_id : string }

type generation_failed = {
  session_id : session_id;
  generation_id : string;
  reason : string option;
}

type user_turn = { session_id : session_id; tree : string; event : string }
type ack = { session_id : session_id; generation_id : string; seq : int }

type rejection_reason =
  | InvalidSession
  | InvalidGeneration
  | InvalidSequence
  | MalformedPayload

type rejection = { session_id : session_id; reason : rejection_reason }

type message =
  | Attach of attach
  | Delta of delta
  | GenerationCompleted of generation_completed
  | GenerationFailed of generation_failed
  | UserTurn of user_turn
  | Ack of ack
  | Rejection of rejection

val encode_message : message -> Yojson.Safe.t
val decode_message : Yojson.Safe.t -> (message, string) result
