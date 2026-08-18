let assert_equal label expected actual =
  if expected <> actual then failwith label

let text = Ribosome_core.Types.Text Templates.Text.{
  kind = "text";
  id = "title";
  text_type = H1;
  content = "Trip planner";
}

let test_encodes_full_template_update () =
  assert_equal "template updates contain a complete normalized tree"
    "{\"protocolVersion\":1,\"type\":\"templateUpdate\",\"sessionId\":\"session-1\",\"revision\":4,\"tree\":{\"kind\":\"text\",\"id\":\"title\",\"text_type\":\"H1\",\"value\":\"Trip planner\"}}"
    (Dream_protocol.ServerMessage.encode_string (Template_update {
      session_id = "session-1";
      revision = 4;
      tree = text;
    }))

let test_decodes_generation_failure () =
  assert_equal "generation failure is visible to the TUI"
    (Ok (Dream_protocol.ServerMessage.Generation_failed {
      session_id = "session-1";
      turn_id = "turn-1";
      message = "model failed";
    }))
    (Dream_protocol.ServerMessage.decode_string
      "{\"protocolVersion\":1,\"type\":\"generationFailed\",\"sessionId\":\"session-1\",\"turnId\":\"turn-1\",\"message\":\"model failed\"}")

let test_rejects_unknown_server_messages () =
  assert_equal "server message tags are closed"
    (Error "unknown server message type")
    (Dream_protocol.ServerMessage.decode_string
      "{\"protocolVersion\":1,\"type\":\"unknown\"}")

let () =
  test_encodes_full_template_update ();
  test_decodes_generation_failure ();
  test_rejects_unknown_server_messages ()
