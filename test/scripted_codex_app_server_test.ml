open Codex_client
open Lwt.Infix

let assert_equal label expected actual =
  if expected <> actual then failwith label

let command = Stdio.command "/bin/sh" ["test/scripted_codex_app_server.sh"]

let receive process =
  Stdio.receive_line process >>= function
  | Some line -> Lwt.return line
  | None -> failwith "scripted app-server exited unexpectedly"

let send process line =
  Stdio.send_line process line >>= function
  | Ok () -> Lwt.return_unit
  | Error Stdio.Closed -> failwith "scripted app-server closed stdin"

let test_scripted_lifecycle () =
  let process = Stdio.start command in
  let result =
    send process "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\"}" >>= fun () ->
    receive process >>= fun initialize ->
    assert_equal "initialize response"
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"userAgent\":\"scripted-codex\",\"codexHome\":\"/tmp/codex\",\"platformFamily\":\"unix\",\"platformOs\":\"test\"}}"
      initialize;
    send process "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"skills/extraRoots/set\"}" >>= fun () ->
    receive process >>= fun _ ->
    send process "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"skills/list\"}" >>= fun () ->
    receive process >>= fun skills ->
    if not (String.contains skills 'r') then failwith "skills response lacks ribosome";
    send process "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"thread/start\"}" >>= fun () ->
    receive process >>= fun _ ->
    send process "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"turn/start\"}" >>= fun () ->
    receive process >>= fun _ ->
    receive process >>= fun delta ->
    receive process >>= fun completed ->
    if not (String.contains delta 'd') || not (String.contains completed 'c') then
      failwith "turn stream lacks delta or completion";
    send process "{\"jsonrpc\":\"2.0\",\"id\":6,\"method\":\"thread/resume\"}" >>= fun () ->
    receive process >>= fun _ ->
    send process "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"turn/start\",\"params\":{\"input\":\"fail\"}}" >>= fun () ->
    receive process >>= fun _ ->
    receive process >>= fun failed ->
    if not (String.contains failed 'f') then failwith "turn failure missing";
    send process "{\"jsonrpc\":\"2.0\",\"id\":8,\"method\":\"turn/interrupt\"}" >>= fun () ->
    receive process >>= fun _ ->
    receive process >>= fun interrupted ->
    if not (String.contains interrupted 'i') then failwith "interrupt completion missing";
    Stdio.shutdown process >|= fun _ -> ()
  in
  Lwt_main.run result

let () = test_scripted_lifecycle ()
