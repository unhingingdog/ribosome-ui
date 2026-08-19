open Codex_client

let assert_equal label expected actual =
  if expected <> actual then failwith label

let skill = Skills.{
  name = "ribosome";
  description = "Generate Ribosome templates";
  path = "/opt/ribosome/skills/ribosome/SKILL.md";
  enabled = true;
}

let request = Turn.{
  thread = Thread.{ id = "thread-1" };
  skill;
  semantic_input = "Create a trip planner.";
  tree = None;
}

let test_starts_restricted_turn () =
  match Turn.start Turn.Idle (Client.create ()) request with
  | Ok (Turn.Requested (Client.Send_line line), _, Turn.Waiting _) ->
    assert_equal "turn includes the skill, semantic input, and restrictions"
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"turn/start\",\"params\":{\"threadId\":\"thread-1\",\"input\":[{\"type\":\"skill\",\"name\":\"ribosome\",\"path\":\"/opt/ribosome/skills/ribosome/SKILL.md\"},{\"type\":\"text\",\"text\":\"Use the ribosome skill. Emit only the requested Ribosome JSON.\\n\\nThere is no existing UI. Generate the initial Ribosome tree.\\n\\nSemantic UI input:\\nCreate a trip planner.\",\"text_elements\":[]}],\"approvalPolicy\":\"never\",\"sandboxPolicy\":{\"type\":\"readOnly\",\"networkAccess\":false}}}"
      line
  | Ok _ | Error _ -> failwith "expected turn/start command"

let test_records_turn_id () =
  let phase = Turn.Waiting (Codex_protocol.JsonRpc.Integer 1) in
  let event = Client.Response {
    request = { Client.id = Codex_protocol.JsonRpc.Integer 1; method_ = "turn/start" };
    result = Ok (`Assoc [("turn", `Assoc [("id", `String "turn-1")])]);
  } in
  assert_equal "turn id is available for generation notifications"
    (Ok (Turn.Turn_started { id = "turn-1" }, Client.create (), Turn.Active { id = "turn-1" }))
    (Turn.receive phase (Client.create ()) event)

let test_rejects_second_turn () =
  assert_equal "one active turn per session" (Error Turn.Already_active)
    (Turn.start (Turn.Active { id = "turn-1" }) (Client.create ()) request)

let () =
  test_starts_restricted_turn ();
  test_records_turn_id ();
  test_rejects_second_turn ()
