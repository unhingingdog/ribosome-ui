(* Versioned harness stream protocol.

   After kickoff, the harness adapter opens a WebSocket to /v1/harness and
   authenticates with the nonce injected at start. It forwards every native
   assistant delta as one harness delta message carrying generation ID and a
   monotonically increasing sequence number. The first delta implicitly starts a
   generation; the server infers generation start from it. Terminal generation
   events become completed or failed. The server sends userTurn messages back to
   the adapter, each containing the full authoritative typed tree plus the
   semantic event. *)

let version = "0.0.0"

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

type user_turn = {
  session_id : session_id;
  tree : string; (* JSON-encoded template *)
  event : string; (* JSON-encoded semantic event *)
}

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

let rejection_reason_to_string = function
  | InvalidSession -> "invalid_session"
  | InvalidGeneration -> "invalid_generation"
  | InvalidSequence -> "invalid_sequence"
  | MalformedPayload -> "malformed_payload"

let rejection_reason_of_string = function
  | "invalid_session" -> Ok InvalidSession
  | "invalid_generation" -> Ok InvalidGeneration
  | "invalid_sequence" -> Ok InvalidSequence
  | "malformed_payload" -> Ok MalformedPayload
  | s -> Error ("unknown rejection reason: " ^ s)

let encode_message msg : Yojson.Safe.t =
  match msg with
  | Attach a ->
      `Assoc
        [
          ("kind", `String "attach");
          ("session_id", `String a.session_id);
          ("harness_session_id", `String a.harness_session_id);
          ("nonce", `String a.nonce);
        ]
  | Delta d ->
      `Assoc
        [
          ("kind", `String "delta");
          ("session_id", `String d.session_id);
          ("generation_id", `String d.generation_id);
          ("seq", `Int d.seq);
          ("content", `String d.content);
        ]
  | GenerationCompleted g ->
      `Assoc
        [
          ("kind", `String "generation_completed");
          ("session_id", `String g.session_id);
          ("generation_id", `String g.generation_id);
        ]
  | GenerationFailed g ->
      `Assoc
        ([
           ("kind", `String "generation_failed");
           ("session_id", `String g.session_id);
           ("generation_id", `String g.generation_id);
         ]
        @ match g.reason with None -> [] | Some r -> [ ("reason", `String r) ])
  | UserTurn u ->
      `Assoc
        [
          ("kind", `String "user_turn");
          ("session_id", `String u.session_id);
          ("tree", `String u.tree);
          ("event", `String u.event);
        ]
  | Ack a ->
      `Assoc
        [
          ("kind", `String "ack");
          ("session_id", `String a.session_id);
          ("generation_id", `String a.generation_id);
          ("seq", `Int a.seq);
        ]
  | Rejection r ->
      `Assoc
        [
          ("kind", `String "rejection");
          ("session_id", `String r.session_id);
          ("reason", `String (rejection_reason_to_string r.reason));
        ]

let ( let* ) = Result.bind

let decode_message json : (message, string) result =
  let kind_field json =
    match json with
    | `Assoc fields -> (
        match Stdlib.List.assoc_opt "kind" fields with
        | Some (`String k) -> Ok (k, fields)
        | _ -> Error "missing or non-string 'kind' field")
    | _ -> Error "expected object"
  in
  let string_field name fields =
    match Stdlib.List.assoc_opt name fields with
    | Some (`String s) -> Ok s
    | _ -> Error ("expected string field: " ^ name)
  in
  let int_field name fields =
    match Stdlib.List.assoc_opt name fields with
    | Some (`Int n) -> Ok n
    | _ -> Error ("expected int field: " ^ name)
  in
  let* kind, fields = kind_field json in
  match kind with
  | "attach" ->
      let* session_id = string_field "session_id" fields in
      let* harness_session_id = string_field "harness_session_id" fields in
      let* nonce = string_field "nonce" fields in
      Ok (Attach { session_id; harness_session_id; nonce })
  | "delta" ->
      let* session_id = string_field "session_id" fields in
      let* generation_id = string_field "generation_id" fields in
      let* seq = int_field "seq" fields in
      let* content = string_field "content" fields in
      Ok (Delta { session_id; generation_id; seq; content })
  | "generation_completed" ->
      let* session_id = string_field "session_id" fields in
      let* generation_id = string_field "generation_id" fields in
      Ok (GenerationCompleted { session_id; generation_id })
  | "generation_failed" ->
      let* session_id = string_field "session_id" fields in
      let* generation_id = string_field "generation_id" fields in
      let reason =
        match Stdlib.List.assoc_opt "reason" fields with
        | Some (`String r) -> Some r
        | _ -> None
      in
      Ok (GenerationFailed { session_id; generation_id; reason })
  | "user_turn" ->
      let* session_id = string_field "session_id" fields in
      let* tree = string_field "tree" fields in
      let* event = string_field "event" fields in
      Ok (UserTurn { session_id; tree; event })
  | "ack" ->
      let* session_id = string_field "session_id" fields in
      let* generation_id = string_field "generation_id" fields in
      let* seq = int_field "seq" fields in
      Ok (Ack { session_id; generation_id; seq })
  | "rejection" ->
      let* session_id = string_field "session_id" fields in
      let* reason_str = string_field "reason" fields in
      let* reason = rejection_reason_of_string reason_str in
      Ok (Rejection { session_id; reason })
  | k -> Error ("unknown message kind: " ^ k)
