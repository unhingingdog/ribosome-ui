let assert_equal label expected actual =
  if expected <> actual then failwith label

let app_server = Codex_client.Stdio.command "/bin/sh" [
  "-c";
  "read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"userAgent\":\"codex\",\"codexHome\":\"/tmp/codex\",\"platformFamily\":\"unix\",\"platformOs\":\"macos\"}}'; read line; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{}}'; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"data\":[{\"cwd\":\"/opt/ribosome\",\"skills\":[{\"name\":\"ribosome\",\"description\":\"Generate UI\",\"path\":\"/opt/ribosome/skills/ribosome/SKILL.md\",\"enabled\":true}],\"errors\":[]}]}}'; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":4,\"result\":{\"thread\":{\"id\":\"thread-1\"}}}'; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":5,\"result\":{\"turn\":{\"id\":\"turn-1\"}}}'";
]

let config = Dream_server.Bootstrap.{
  interface = "127.0.0.1";
  port = 9010;
  codex_command = app_server;
  skill_root = "/opt/ribosome/skills";
  cwd = "/opt/ribosome";
}

let test_starts_initial_prompt_turn () =
  let ready = match Lwt_main.run (Dream_server.Bootstrap.start config) with
    | Ok ready -> ready
    | Error _ -> failwith "expected bootstrap"
  in
  let session = Ribosome_session.Session.create ~initial_prompt:"Explain this change." "session-1" in
  match Lwt_main.run (Dream_server.FirstTurn.start ready session) with
  | Ok (_, session) ->
    assert_equal "first turn attaches a Codex thread" (Some Codex_client.Thread.{ id = "thread-1" }) session.thread;
    assert_equal "first turn records the active generation"
      (Some Ribosome_session.Session.{ turn = Codex_client.Turn.{ id = "turn-1" }; cancellation_requested = false })
      session.generation
  | Error _ -> failwith "expected initial turn"

let () = test_starts_initial_prompt_turn ()
