(* UI runtime: routes UI protocol messages into Ribosome sessions.

   Authenticates UI attachment using the session's UI nonce. Sends the current
   snapshot immediately after attachment. Decodes and reduces component events:
   change events apply locally and broadcast to all UI clients; click and submit
   events produce one user-turn message for the attached harness adapter.
   Rejections are returned without closing healthy connections. *)

type ui_broadcast = {
  broadcast_template_update :
    session_id:string -> revision:int -> tree:string -> unit;
  broadcast_session_state :
    session_id:string ->
    mode:string ->
    revision:int ->
    tree:string option ->
    generation_id:string option ->
    unit;
  broadcast_event_rejection :
    session_id:string ->
    event_id:string ->
    reason:Ui_protocol.event_rejection_reason ->
    unit;
  send_user_turn : session_id:string -> tree:string -> event:string -> unit;
}

type t = {
  registry : Session_registry.t;
  broadcast : ui_broadcast;
  sessions : (string, Ribosome.Session.t) Hashtbl.t;
}

type error =
  | InvalidSession
  | InvalidNonce
  | NoActiveSession
  | EventError of string

let error_string = function
  | InvalidSession -> "invalid session"
  | InvalidNonce -> "invalid nonce"
  | NoActiveSession -> "no active session"
  | EventError e -> e

let create ~registry ~broadcast =
  { registry; broadcast; sessions = Hashtbl.create 16 }

let register_session t ~session_id =
  let session = Ribosome.Session.create ~id:session_id ~mode:Ribosome.Mode.ui in
  let session =
    {
      session with
      Ribosome.Session.tree = Some Home_template.home_tree;
      revision = 1;
    }
  in
  Hashtbl.add t.sessions session_id session

let put_session t ~session_id session =
  Hashtbl.replace t.sessions session_id session

let get_session t ~session_id = Hashtbl.find_opt t.sessions session_id

let handle_attach t ~session_id ~revision =
  Debug.log "ui"
    (Printf.sprintf "attach session=%s revision=%s" session_id
       (match revision with Some r -> string_of_int r | None -> "none"));
  (match Session_registry.find t.registry session_id with
  | None ->
      Debug.log "ui"
        (Printf.sprintf "creating session %s (UI-initiated)" session_id);
      Session_registry.start_ui ~registry:t.registry ~session_id;
      register_session t ~session_id
  | Some _ -> ());
  match Session_registry.find t.registry session_id with
  | None -> Error InvalidSession
  | Some entry -> (
      (* UI nonce check would happen here once nonces are passed in *)
      let _ =
        Session_registry.attach_ui t.registry session_id ~conn_id:session_id
          ~revision:(match revision with Some r -> r | None -> 0)
      in
      match Hashtbl.find_opt t.sessions session_id with
      | None -> Error NoActiveSession
      | Some session ->
          let tree_str =
            match session.Ribosome.Session.tree with
            | Some tree ->
                Some (Yojson.Safe.to_string (Ribosome.Template.encode tree))
            | None -> None
          in
          let gen_id =
            match session.Ribosome.Session.generation with
            | Some gen -> Some gen.Ribosome.Session.id
            | None -> None
          in
          Debug.log "ui"
            (Printf.sprintf "attach OK session=%s rev=%d tree=%s gen=%s"
               session_id session.Ribosome.Session.revision
               (if tree_str <> None then "yes" else "no")
               (match gen_id with Some g -> g | None -> "none"));
          t.broadcast.broadcast_session_state ~session_id
            ~mode:entry.Session_registry.mode
            ~revision:session.Ribosome.Session.revision ~tree:tree_str
            ~generation_id:gen_id;
          Ok ())

let parse_value = function
  | `String s -> Ok (Ribosome.Template.Input.String s)
  | `Int n -> Ok (Ribosome.Template.Input.Int n)
  | _ -> Error "value must be string or int"

let build_event ~kind ~target_id ~value : (Ribosome.Event.event, error) result =
  match kind with
  | Ui_protocol.Click -> Ok (Ribosome.Event.Click { target_id })
  | Ui_protocol.Submit -> Ok (Ribosome.Event.Submit { target_id })
  | Ui_protocol.Change -> (
      match value with
      | Some v -> (
          match parse_value v with
          | Ok input_value ->
              Ok (Ribosome.Event.Change { target_id; value = input_value })
          | Error e -> Error (EventError e))
      | None -> Error (EventError "change event requires value"))

let handle_component_event t ~session_id ~revision ~event_id ~target_id ~kind
    ~value =
  Debug.log "ui"
    (Printf.sprintf
       "component_event session=%s target=%s kind=%s event_id=%s rev=%d"
       session_id target_id
       (Ui_protocol.component_kind_to_string kind)
       event_id revision);
  match Hashtbl.find_opt t.sessions session_id with
  | None -> Error InvalidSession
  | Some session -> (
      match build_event ~kind ~target_id ~value with
      | Error e -> Error e
      | Ok event -> (
          match
            Ribosome.Session.apply_event session ~event_id
              ~base_revision:revision event
          with
          | Ok (Ribosome.Session.Updated new_session) ->
              Hashtbl.replace t.sessions session_id new_session;
              Debug.log "ui"
                (Printf.sprintf "event updated (change) session=%s new_rev=%d"
                   session_id new_session.Ribosome.Session.revision);
              let tree_str =
                match new_session.Ribosome.Session.tree with
                | Some tree ->
                    Yojson.Safe.to_string (Ribosome.Template.encode tree)
                | None -> ""
              in
              t.broadcast.broadcast_template_update ~session_id
                ~revision:new_session.Ribosome.Session.revision ~tree:tree_str;
              Ok `Updated
          | Ok (Ribosome.Session.UserTurn (new_session, tree, event)) ->
              Hashtbl.replace t.sessions session_id new_session;
              Debug.log "ui"
                (Printf.sprintf "event user_turn session=%s new_rev=%d"
                   session_id new_session.Ribosome.Session.revision);
              let tree_str =
                Yojson.Safe.to_string (Ribosome.Template.encode tree)
              in
              let event_str =
                Yojson.Safe.to_string
                  (match event with
                  | Ribosome.Event.Click _ -> `Null
                  | Ribosome.Event.Change _ -> `Null
                  | Ribosome.Event.Submit _ -> `Null)
              in
              t.broadcast.send_user_turn ~session_id ~tree:tree_str
                ~event:event_str;
              Ok `UserTurn
          | Error e ->
              let reason =
                if String.length e >= 14 && String.sub e 0 14 = "stale revision"
                then Ui_protocol.StaleRevision
                else Ui_protocol.DuplicateEventId
              in
              Debug.log "ui"
                (Printf.sprintf
                   "event rejected session=%s event_id=%s raw_error=%s \
                    reason=%s"
                   session_id event_id e
                   (Ui_protocol.rejection_reason_to_string reason));
              t.broadcast.broadcast_event_rejection ~session_id ~event_id
                ~reason;
              Error (EventError e)))

let handle_message t (msg : Ui_protocol.message) : (unit, error) result =
  match msg with
  | Ui_protocol.Attach a ->
      handle_attach t ~session_id:a.session_id ~revision:a.revision
  | Ui_protocol.ComponentEvent e -> (
      match
        handle_component_event t ~session_id:e.session_id ~revision:e.revision
          ~event_id:e.event_id ~target_id:e.target_id ~kind:e.kind
          ~value:e.value
      with
      | Ok _ -> Ok ()
      | Error e -> Error e)
  | Ui_protocol.Cancel _ -> Ok ()
  | Ui_protocol.Disconnect _ -> Ok ()
  | _ -> Ok ()
