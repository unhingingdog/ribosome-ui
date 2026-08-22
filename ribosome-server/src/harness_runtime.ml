(* Harness runtime: routes harness protocol messages into Ribosome sessions.

   The runtime holds Ribosome sessions keyed by session ID. It authenticates
   harness attachment using the nonce injected at kickoff, maps deltas to
   Session.feed_delta, and broadcasts committed revisions to attached UI
   clients through a broadcast port. *)

type broadcast = {
  broadcast_template_update :
    session_id:string -> revision:int -> tree:string -> unit;
}

type t = {
  registry : Session_registry.t;
  broadcast : broadcast;
  sessions : (string, Ribosome.Session.t) Hashtbl.t;
}

type delta_result = Updated | Pending | Corrupted
type handle_result = Attached | DeltaResult of delta_result | Completed
type rejection = Harness_protocol.rejection_reason

type error =
  | InvalidSession
  | InvalidGeneration of string
  | InvalidSequence of string

let to_rejection = function
  | InvalidSession -> Harness_protocol.InvalidSession
  | InvalidGeneration _ -> Harness_protocol.InvalidGeneration
  | InvalidSequence _ -> Harness_protocol.InvalidSequence

let create ~registry ~broadcast =
  { registry; broadcast; sessions = Hashtbl.create 16 }

let register_session t ~session_id =
  let session = Ribosome.Session.create ~id:session_id ~mode:Ribosome.Mode.ui in
  Hashtbl.add t.sessions session_id session

let handle_attach t ~session_id ~harness_session_id ~nonce =
  match Session_registry.find t.registry session_id with
  | None -> Error InvalidSession
  | Some entry ->
      if entry.Session_registry.harness_nonce <> nonce then Error InvalidSession
      else if entry.Session_registry.harness_session_id <> harness_session_id
      then Error InvalidSession
      else
        let _ =
          Session_registry.attach_harness t.registry session_id
            ~conn_id:session_id
        in
        Ok ()

let handle_delta t ~session_id ~generation_id ~seq ~content :
    (delta_result, error) result =
  match Hashtbl.find_opt t.sessions session_id with
  | None -> Error InvalidSession
  | Some session -> (
      let session =
        match session.Ribosome.Session.generation with
        | Some gen when gen.Ribosome.Session.id = generation_id -> session
        | _ -> (
            match
              Ribosome.Session.start_generation session ~gen_id:generation_id
            with
            | Ok s -> s
            | Error _ -> session)
      in
      match
        Ribosome.Session.feed_delta session ~gen_id:generation_id ~seq
          ~delta:content
      with
      | Ok (session, Ribosome.Incremental.Updated tree) ->
          Hashtbl.replace t.sessions session_id session;
          t.broadcast.broadcast_template_update ~session_id
            ~revision:session.Ribosome.Session.revision
            ~tree:(Yojson.Safe.to_string (Ribosome.Template.encode tree));
          Ok Updated
      | Ok (session, Ribosome.Incremental.Pending) ->
          Hashtbl.replace t.sessions session_id session;
          Ok Pending
      | Ok (session, Ribosome.Incremental.Rejected _) ->
          Hashtbl.replace t.sessions session_id session;
          Ok Pending
      | Ok (session, Ribosome.Incremental.Corrupted) ->
          Hashtbl.replace t.sessions session_id session;
          Ok Corrupted
      | Error e -> Error (InvalidSequence e))

let handle_generation_completed t ~session_id ~generation_id :
    (unit, error) result =
  match Hashtbl.find_opt t.sessions session_id with
  | None -> Error InvalidSession
  | Some session -> (
      match
        Ribosome.Session.complete_generation session ~gen_id:generation_id
      with
      | Ok session ->
          Hashtbl.replace t.sessions session_id session;
          Ok ()
      | Error e -> Error (InvalidGeneration e))

let handle_generation_failed t ~session_id ~generation_id : (unit, error) result
    =
  match Hashtbl.find_opt t.sessions session_id with
  | None -> Error InvalidSession
  | Some session -> (
      match Ribosome.Session.fail_generation session ~gen_id:generation_id with
      | Ok session ->
          Hashtbl.replace t.sessions session_id session;
          Ok ()
      | Error e -> Error (InvalidGeneration e))

let handle_message t (msg : Harness_protocol.message) :
    (handle_result, rejection) result =
  match msg with
  | Harness_protocol.Attach a -> (
      match
        handle_attach t ~session_id:a.session_id
          ~harness_session_id:a.harness_session_id ~nonce:a.nonce
      with
      | Ok () -> Ok Attached
      | Error r -> Error (to_rejection r))
  | Harness_protocol.Delta d -> (
      match
        handle_delta t ~session_id:d.session_id ~generation_id:d.generation_id
          ~seq:d.seq ~content:d.content
      with
      | Ok result -> Ok (DeltaResult result)
      | Error r -> Error (to_rejection r))
  | Harness_protocol.GenerationCompleted g -> (
      match
        handle_generation_completed t ~session_id:g.session_id
          ~generation_id:g.generation_id
      with
      | Ok () -> Ok Completed
      | Error r -> Error (to_rejection r))
  | Harness_protocol.GenerationFailed g -> (
      match
        handle_generation_failed t ~session_id:g.session_id
          ~generation_id:g.generation_id
      with
      | Ok () -> Ok Completed
      | Error r -> Error (to_rejection r))
  | _ -> Error Harness_protocol.MalformedPayload
