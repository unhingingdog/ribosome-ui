let assert_equal label expected actual =
  if expected <> actual then failwith label

let test_new_session_negotiation () =
  let endpoint = Dream_server.Websocket.create () in
  match Dream_server.Websocket.negotiate endpoint
    Dream_protocol.ClientMessage.(New_session { initial_prompt = "Explain this change." }) with
  | Ok { session; connection_id; message = Dream_protocol.ServerMessage.Session_state { revision; tree; _ } } ->
    assert_equal "new sessions receive a stable session ID" "session-1" session.id;
    assert_equal "connections receive a stable connection ID" "connection-1" connection_id;
    assert_equal "session retains the consumer's first turn input" "Explain this change." session.initial_prompt;
    assert_equal "new sessions begin at revision zero" 0 revision;
    assert_equal "new sessions begin with no generated tree" None tree
  | Ok _ | Error _ -> failwith "expected new session state"

let test_resume_and_disconnect () =
  let endpoint = Dream_server.Websocket.create () in
  let first = match Dream_server.Websocket.negotiate endpoint
    Dream_protocol.ClientMessage.(New_session { initial_prompt = "Explain this change." }) with
    | Ok accepted -> accepted
    | Error _ -> failwith "expected new session"
  in
  let resumed = match Dream_server.Websocket.negotiate endpoint
    (Dream_protocol.ClientMessage.Resume_session { session_id = first.session.id }) with
    | Ok accepted -> accepted
    | Error _ -> failwith "expected resumed session"
  in
  assert_equal "resume retains the same session" first.session.id resumed.session.id;
  Dream_server.Websocket.disconnect endpoint resumed.session.id resumed.connection_id;
  match Dream_runtime.Runtime.find_session !(endpoint.registry) resumed.session.id with
  | Some session ->
    assert_equal "connection cleanup removes only the disconnected connection"
      [first.connection_id] session.connections
  | None -> failwith "expected resumed session"

let test_rejects_events_before_negotiation () =
  let endpoint = Dream_server.Websocket.create () in
  assert_equal "the first WebSocket message establishes a session"
    (Error Dream_server.Websocket.Invalid_initial_message)
    (Dream_server.Websocket.negotiate endpoint (Dream_protocol.ClientMessage.Cancel { session_id = "session-1" }))

let test_dispatches_semantic_events () =
  let endpoint = Dream_server.Websocket.create () in
  let accepted = match Dream_server.Websocket.negotiate endpoint
    Dream_protocol.ClientMessage.(New_session { initial_prompt = "Explain this change." }) with
    | Ok accepted -> accepted
    | Error _ -> failwith "expected new session"
  in
  assert_equal "semantic events reduce against the session state"
    (Error (Dream_server.Websocket.Event_rejected {
      session_id = "session-1";
      event_id = "event-1";
      reason = "no template";
    }))
    (Dream_server.Websocket.dispatch endpoint Dream_protocol.ClientMessage.(Component_event {
      session_id = accepted.session.id;
      event_id = "event-1";
      base_revision = 0;
      event = Click { id = "save" };
    }))

let () =
  test_new_session_negotiation ();
  test_resume_and_disconnect ();
  test_rejects_events_before_negotiation ();
  test_dispatches_semantic_events ()
