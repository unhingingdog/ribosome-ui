let assert_equal label expected actual =
  if expected <> actual then failwith label

let test_encodes_component_event () =
  let message = Dream_protocol.ClientMessage.Component_event {
    session_id = "session-1";
    event_id = "event-1";
    base_revision = 4;
    event = Submit {
      id = "profile";
      values = [("name", Ribosome_core.Types.String "Alice")];
    };
  } in
  assert_equal "component events use the versioned wire format"
    "{\"protocolVersion\":1,\"type\":\"componentEvent\",\"sessionId\":\"session-1\",\"eventId\":\"event-1\",\"baseRevision\":4,\"event\":{\"type\":\"submit\",\"id\":\"profile\",\"values\":[{\"id\":\"name\",\"value\":\"Alice\"}]}}"
    (Dream_protocol.ClientMessage.encode_string message)

let test_decodes_resume () =
  assert_equal "resume identifies a session"
    (Ok (Dream_protocol.ClientMessage.Resume_session { session_id = "session-1" }))
    (Dream_protocol.ClientMessage.decode_string
      "{\"protocolVersion\":1,\"type\":\"resumeSession\",\"sessionId\":\"session-1\"}")

let test_rejects_unknown_versions () =
  assert_equal "protocol version is mandatory"
    (Error "unsupported protocol version")
    (Dream_protocol.ClientMessage.decode_string "{\"protocolVersion\":2,\"type\":\"newSession\"}")

let () =
  test_encodes_component_event ();
  test_decodes_resume ();
  test_rejects_unknown_versions ()
