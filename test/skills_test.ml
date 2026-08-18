open Codex_client

let assert_equal label expected actual =
  if expected <> actual then failwith label

let root = "/opt/ribosome/skills"
let cwd = "/opt/ribosome"

let response client line =
  match Client.receive client line with
  | (Client.Response _ as event), client -> event, client
  | _ -> failwith "expected correlated response"

let test_registers_package_skill_root () =
  match Skills.start Skills.Not_started (Client.create ()) root cwd with
  | Ok (Skills.Requested (Client.Send_line line), _, Skills.Setting_extra_roots _) ->
    assert_equal "package skill root is registered"
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"skills/extraRoots/set\",\"params\":{\"extraRoots\":[\"/opt/ribosome/skills\"]}}"
      line
  | Ok _ | Error _ -> failwith "expected skill-root registration"

let test_loads_ribosome_skill () =
  let _, _, phase = match Skills.start Skills.Not_started (Client.create ()) root cwd with
    | Ok result -> result
    | Error _ -> failwith "expected skill-root registration"
  in
  let registered = Client.create () |> fun client ->
    let _, _, client = Client.request client "skills/extraRoots/set" (Some (Skills.extra_roots_params root)) in
    client
  in
  let event, client = response registered "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}" in
  let outcome, client, phase = match Skills.receive phase client event with
    | Ok result -> result
    | Error _ -> failwith "expected skills/list request"
  in
  assert_equal "skills are force-reloaded"
    (Skills.Requested (Client.Send_line "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"skills/list\",\"params\":{\"cwds\":[\"/opt/ribosome\"],\"forceReload\":true}}")) outcome;
  let event, client = response client
    "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{\"data\":[{\"cwd\":\"/opt/ribosome\",\"skills\":[{\"name\":\"ribosome\",\"description\":\"Generate UI\",\"path\":\"/opt/ribosome/skills/ribosome/SKILL.md\",\"scope\":\"extra_root\",\"enabled\":true}],\"errors\":[]}]}}" in
  match Skills.receive phase client event with
  | Ok (Skills.Skill_ready skill, _, Skills.Ready _) -> assert_equal "ribosome skill is ready" "ribosome" skill.name
  | Ok _ | Error _ -> failwith "expected ready ribosome skill"

let test_rejects_missing_skill () =
  let phase = Skills.Listing (Codex_protocol.JsonRpc.Integer 2) in
  let event = Client.Response {
    request = { Client.id = Codex_protocol.JsonRpc.Integer 2; method_ = "skills/list" };
    result = Ok (`Assoc [("data", `List [])]);
  } in
  assert_equal "missing ribosome skill blocks readiness" (Error Skills.Missing_ribosome_skill)
    (Skills.receive phase (Client.create ()) event)

let () =
  test_registers_package_skill_root ();
  test_loads_ribosome_skill ();
  test_rejects_missing_skill ()
