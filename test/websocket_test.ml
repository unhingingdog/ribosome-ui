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

let test_starts_initial_turn_when_codex_is_available () =
  let app_server = Codex_client.Stdio.command "/bin/sh" [
    "-c";
    "read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"userAgent\":\"codex\",\"codexHome\":\"/tmp/codex\",\"platformFamily\":\"unix\",\"platformOs\":\"macos\"}}'; read line; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{}}'; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"data\":[{\"cwd\":\"/opt/ribosome\",\"skills\":[{\"name\":\"ribosome\",\"description\":\"Generate UI\",\"path\":\"/opt/ribosome/skills/ribosome/SKILL.md\",\"enabled\":true}],\"errors\":[]}]}}'; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":4,\"result\":{\"thread\":{\"id\":\"thread-1\"}}}'; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":5,\"result\":{\"turn\":{\"id\":\"turn-1\"}}}'";
  ] in
  let ready = match Lwt_main.run (Dream_server.Bootstrap.start Dream_server.Bootstrap.{
    interface = "127.0.0.1";
    port = 9010;
    codex_command = app_server;
    skill_root = "/opt/ribosome/skills";
    cwd = "/opt/ribosome";
  }) with
    | Ok ready -> ready
    | Error _ -> failwith "expected bootstrap"
  in
  let endpoint = Dream_server.Websocket.create ~ready () in
  let accepted = match Dream_server.Websocket.negotiate endpoint
    Dream_protocol.ClientMessage.(New_session { initial_prompt = "Explain this change." }) with
    | Ok accepted -> accepted
    | Error _ -> failwith "expected new session"
  in
  match Lwt_main.run (Dream_server.Websocket.start_initial_turn endpoint accepted.session.id) with
  | Ok (session, Dream_protocol.ServerMessage.Generation_started { turn_id; _ }) ->
    assert_equal "the initial prompt starts a Codex generation" "turn-1" turn_id;
    assert_equal "the active generation remains session-owned" true (Option.is_some session.generation);
    ignore (Lwt_main.run (Codex_client.Stdio.shutdown ready.process))
  | Ok _ | Error _ -> failwith "expected initial generation"

let test_pump_commits_streamed_templates () =
  let app_server = Codex_client.Stdio.command "/bin/sh" [
    "-c";
    "read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"userAgent\":\"codex\",\"codexHome\":\"/tmp/codex\",\"platformFamily\":\"unix\",\"platformOs\":\"macos\"}}'; read line; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{}}'; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"data\":[{\"cwd\":\"/opt/ribosome\",\"skills\":[{\"name\":\"ribosome\",\"description\":\"Generate UI\",\"path\":\"/opt/ribosome/skills/ribosome/SKILL.md\",\"enabled\":true}],\"errors\":[]}]}}'; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":4,\"result\":{\"thread\":{\"id\":\"thread-1\"}}}'; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":5,\"result\":{\"turn\":{\"id\":\"turn-1\"}}}'; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"method\":\"item/agentMessage/delta\",\"params\":{\"threadId\":\"thread-1\",\"turnId\":\"turn-1\",\"itemId\":\"item-1\",\"delta\":\"{\\\"kind\\\":\\\"text\\\",\\\"id\\\":\\\"title\\\",\\\"text_type\\\":\\\"Paragraph\\\",\\\"value\\\":\\\"After\\\"}\"}}'; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"method\":\"turn/completed\",\"params\":{\"threadId\":\"thread-1\",\"turn\":{\"id\":\"turn-1\",\"status\":\"completed\"}}}'";
  ] in
  let ready = match Lwt_main.run (Dream_server.Bootstrap.start Dream_server.Bootstrap.{
    interface = "127.0.0.1";
    port = 9010;
    codex_command = app_server;
    skill_root = "/opt/ribosome/skills";
    cwd = "/opt/ribosome";
  }) with
    | Ok ready -> ready
    | Error _ -> failwith "expected bootstrap"
  in
  let endpoint = Dream_server.Websocket.create ~ready () in
  let accepted = match Dream_server.Websocket.negotiate endpoint
    Dream_protocol.ClientMessage.(New_session { initial_prompt = "Explain this change." }) with
    | Ok accepted -> accepted
    | Error _ -> failwith "expected new session"
  in
  let initial_session = match Lwt_main.run (Dream_server.Websocket.start_initial_turn endpoint accepted.session.id) with
    | Ok (session, _) -> session
    | Error _ -> failwith "expected initial generation"
  in
  Lwt_main.run (Dream_server.Websocket.pump_once endpoint);
  Lwt_main.run (Dream_server.Websocket.pump_once endpoint);
  match Dream_runtime.Runtime.find_session !(endpoint.registry) initial_session.id with
  | Some session ->
    assert_equal "Codex deltas update the authoritative tree" true (Option.is_some session.tree);
    assert_equal "completion clears the active generation" None session.generation
  | None -> failwith "expected session"

let test_pump_starts_follow_up_turns () =
  let app_server = Codex_client.Stdio.command "/bin/sh" [
    "-c";
    "read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"userAgent\":\"codex\",\"codexHome\":\"/tmp/codex\",\"platformFamily\":\"unix\",\"platformOs\":\"macos\"}}'; read line; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{}}'; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"data\":[{\"cwd\":\"/opt/ribosome\",\"skills\":[{\"name\":\"ribosome\",\"description\":\"Generate UI\",\"path\":\"/opt/ribosome/skills/ribosome/SKILL.md\",\"enabled\":true}],\"errors\":[]}]}}'; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":4,\"result\":{\"turn\":{\"id\":\"turn-2\"}}}'";
  ] in
  let ready = match Lwt_main.run (Dream_server.Bootstrap.start Dream_server.Bootstrap.{
    interface = "127.0.0.1"; port = 9010; codex_command = app_server;
    skill_root = "/opt/ribosome/skills"; cwd = "/opt/ribosome";
  }) with
    | Ok ready -> ready
    | Error _ -> failwith "expected bootstrap"
  in
  let endpoint = Dream_server.Websocket.create ~ready () in
  let form = Ribosome_core.Types.Submittable Templates.Submittable.{
    kind = "submittable";
    id = "form";
    value = [];
    button = Some Templates.Button.{ kind = "button"; id = "save"; label = "Save"; action = Submit; disabled = None };
  } in
  let session = match Ribosome_session.Session.attach_thread
    (Ribosome_session.Session.create ~initial_prompt:"Initial request" "session-1")
    Codex_client.Thread.{ id = "thread-1" } with
    | Ok session -> { session with tree = Some form }
    | Error _ -> failwith "expected thread"
  in
  let registry = match Dream_runtime.Runtime.add_session !(endpoint.registry) session with
    | Ok registry -> registry
    | Error _ -> failwith "expected session"
  in
  endpoint.registry := registry;
  match Lwt_main.run (Dream_server.Websocket.enqueue_turn endpoint "session-1"
    Dream_protocol.ClientMessage.(Click { id = "save" })) with
  | Error _ -> failwith "expected queued turn"
  | Ok () ->
    Lwt_main.run (Dream_server.Websocket.pump_once endpoint);
    match Dream_runtime.Runtime.find_session !(endpoint.registry) "session-1" with
    | Some session ->
      assert_equal "follow-up click starts another Codex turn" true (Option.is_some session.generation)
    | None -> failwith "expected session"

let () =
  test_new_session_negotiation ();
  test_resume_and_disconnect ();
  test_rejects_events_before_negotiation ();
  test_dispatches_semantic_events ();
  test_starts_initial_turn_when_codex_is_available ();
  test_pump_commits_streamed_templates ();
  test_pump_starts_follow_up_turns ()
