open Codex_client
open Lwt.Infix

let assert_equal label expected actual =
  if expected <> actual then failwith label

let echo_command = Stdio.command "/bin/sh" [
  "-c";
  "printf 'starting\\n' >&2; while IFS= read -r line; do printf '%s\\n' \"$line\"; done";
]

let test_round_trips_lines () =
  let process = Stdio.start echo_command in
  let result =
    Stdio.send_line process "hello" >>= function
    | Error Stdio.Closed -> failwith "process unexpectedly closed"
    | Ok () ->
      Stdio.receive_line process >>= function
      | Some line ->
        assert_equal "stdout is line framed" "hello" line;
        Stdio.shutdown process >|= fun _ -> ()
      | None -> failwith "process exited before replying"
  in
  Lwt_main.run result

let test_captures_bounded_stderr () =
  let process = Stdio.start ~stderr_limit:4 echo_command in
  let result = Stdio.shutdown process >|= fun _ ->
    assert_equal "stderr is bounded" "star" (Stdio.stderr process)
  in
  Lwt_main.run result

let test_rejects_writes_after_shutdown () =
  let process = Stdio.start echo_command in
  let result =
    Stdio.shutdown process >>= fun _ ->
    Stdio.send_line process "hello" >|= fun result ->
    assert_equal "closed process cannot receive writes" (Error Stdio.Closed) result
  in
  Lwt_main.run result

let () =
  test_round_trips_lines ();
  test_captures_bounded_stderr ();
  test_rejects_writes_after_shutdown ()
