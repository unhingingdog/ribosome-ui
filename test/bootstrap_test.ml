let assert_equal label expected actual =
  if expected <> actual then failwith label

let app_server = Codex_client.Stdio.command "/bin/sh" [
  "-c";
  "read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"userAgent\":\"codex\",\"codexHome\":\"/tmp/codex\",\"platformFamily\":\"unix\",\"platformOs\":\"macos\"}}'; read line; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{}}'; read line; printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"data\":[{\"cwd\":\"/opt/ribosome\",\"skills\":[{\"name\":\"ribosome\",\"description\":\"Generate UI\",\"path\":\"/opt/ribosome/skills/ribosome/SKILL.md\",\"enabled\":true}],\"errors\":[]}]}}'";
]

let config = Dream_server.Bootstrap.{
  interface = "127.0.0.1";
  port = 9010;
  codex_command = app_server;
  skill_root = "/opt/ribosome/skills";
  cwd = "/opt/ribosome";
}

let test_bootstraps_ready_codex () =
  match Lwt_main.run (Dream_server.Bootstrap.start config) with
  | Ok ready ->
    assert_equal "bootstrap records the ready Ribosome skill" "ribosome" ready.skill.name;
    assert_equal "bootstrap records Codex server metadata" "codex" ready.server_info.user_agent;
    assert_equal "bootstrap retains the configured working directory" "/opt/ribosome" ready.cwd;
    ignore (Lwt_main.run (Codex_client.Stdio.shutdown ready.process))
  | Error _ -> failwith "expected ready Codex app-server"

let test_declares_health_payload () =
  assert_equal "health endpoint identifies a ready server"
    "{\"status\":\"ready\"}" Dream_server.Bootstrap.health_json

let () =
  test_bootstraps_ready_codex ();
  test_declares_health_payload ()
