open Lwt.Infix

let assert_equal label expected actual =
  if expected <> actual then failwith label

let session = Ribosome_session.Session.create "session-1"

let test_registry_owns_sessions () =
  let registry = match Dream_runtime.Runtime.add_session Dream_runtime.Runtime.empty_registry session with
    | Ok registry -> registry
    | Error _ -> failwith "expected session insertion"
  in
  assert_equal "registry finds a session by its stable ID" (Some session)
    (Dream_runtime.Runtime.find_session registry "session-1");
  assert_equal "registry rejects duplicate session IDs"
    (Error Dream_runtime.Runtime.Session_already_exists)
    (Dream_runtime.Runtime.add_session registry session)

module Capture = struct
  type t = (string * Dream_protocol.ServerMessage.t) list ref

  let send messages connection_id message =
    messages := !messages @ [(connection_id, message)];
    Lwt.return_unit
end

module Broadcast = Dream_runtime.Runtime.Broadcast (Capture)

let test_broadcasts_template_updates_to_connections () =
  let session = { session with connections = ["first"; "second"] } in
  let tree = Ribosome_core.Types.Text Templates.Text.{
    kind = "text";
    id = "title";
    text_type = Paragraph;
    content = "Trip planner";
  } in
  let messages = ref [] in
  Lwt_main.run (Broadcast.emission messages session
    (Ribosome_session.Session.Template_updated { revision = 1; tree }));
  assert_equal "all connections receive the same full update"
    [
      ("first", Dream_protocol.ServerMessage.Template_update { session_id = "session-1"; revision = 1; tree });
      ("second", Dream_protocol.ServerMessage.Template_update { session_id = "session-1"; revision = 1; tree });
    ]
    !messages

let test_interprets_codex_lines () =
  let process = Codex_client.Stdio.start (Codex_client.Stdio.command "/bin/sh" [
    "-c";
    "IFS= read -r line; printf '%s\\n' \"$line\"";
  ]) in
  let result =
    Dream_runtime.Runtime.interpret_codex_command process (Codex_client.Client.Send_line "request") >>= function
    | Error Codex_client.Stdio.Closed -> failwith "process unexpectedly closed"
    | Ok () ->
      Codex_client.Stdio.receive_line process >>= function
      | Some line ->
        assert_equal "Codex commands are written to managed stdio" "request" line;
        Codex_client.Stdio.shutdown process >|= fun _ -> ()
      | None -> failwith "process exited before receiving command"
  in
  Lwt_main.run result

let () =
  test_registry_owns_sessions ();
  test_broadcasts_template_updates_to_connections ();
  test_interprets_codex_lines ()
