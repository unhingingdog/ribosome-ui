let read_fixture name =
  let cwd = Sys.getcwd () in
  let paths =
    [
      "protocol-fixtures/" ^ name ^ ".json";
      "../../../protocol-fixtures/" ^ name ^ ".json";
      "../../../../protocol-fixtures/" ^ name ^ ".json";
      cwd ^ "/protocol-fixtures/" ^ name ^ ".json";
      cwd ^ "/../../../protocol-fixtures/" ^ name ^ ".json";
      cwd ^ "/../../../../protocol-fixtures/" ^ name ^ ".json";
    ]
  in
  let rec try_paths = function
    | [] -> Alcotest.fail ("cannot find fixture " ^ name ^ " from cwd=" ^ cwd)
    | p :: rest ->
        if Sys.file_exists p then (
          let ic = open_in p in
          let len = in_channel_length ic in
          let s = really_input_string ic len in
          close_in ic;
          s)
        else try_paths rest
  in
  try_paths paths

let decode json_str =
  match Yojson.Safe.from_string json_str with
  | json -> Ribosome_server_lib.Ui_protocol.decode_message json
  | exception Yojson.Json_error msg -> Error ("json parse error: " ^ msg)

let roundtrip name expected =
  let json_str = read_fixture name in
  let decoded = decode json_str in
  Alcotest.(check (result string string))
    ("decode " ^ name) (Ok "decoded")
    (Result.map (fun _ -> "decoded") decoded);
  let encoded =
    match decoded with
    | Ok msg -> Ribosome_server_lib.Ui_protocol.encode_message msg
    | Error e -> Alcotest.fail ("decode failed: " ^ e)
  in
  let redecoded = Ribosome_server_lib.Ui_protocol.decode_message encoded in
  Alcotest.(check (result string string))
    ("roundtrip " ^ name)
    (Result.map (fun _ -> "decoded") decoded)
    (Result.map (fun _ -> "decoded") redecoded);
  Alcotest.(check (result string string))
    ("roundtrip stable " ^ name)
    (Ok expected)
    (Result.map (fun _ -> expected) redecoded)

let test_attach () = roundtrip "attach" "attach"

let test_component_event_click () =
  roundtrip "component_event_click" "component_event"

let test_component_event_change () =
  roundtrip "component_event_change" "component_event"

let test_cancel () = roundtrip "cancel" "cancel"
let test_disconnect () = roundtrip "disconnect" "disconnect"
let test_session_state () = roundtrip "session_state" "session_state"
let test_template_update () = roundtrip "template_update" "template_update"

let test_generation_started () =
  roundtrip "generation_started" "generation_lifecycle"

let test_generation_delta () =
  roundtrip "generation_delta" "generation_lifecycle"

let test_generation_completed () =
  roundtrip "generation_completed" "generation_lifecycle"

let test_generation_failed () =
  roundtrip "generation_failed" "generation_lifecycle"

let test_event_rejection_stale () =
  roundtrip "event_rejection_stale" "event_rejection"

let test_event_rejection_duplicate () =
  roundtrip "event_rejection_duplicate" "event_rejection"

let string_contains haystack needle =
  let rec search i =
    if i > String.length haystack - String.length needle then false
    else if String.sub haystack i (String.length needle) = needle then true
    else search (i + 1)
  in
  search 0

let test_unknown_kind () =
  let json = `Assoc [ ("kind", `String "unknown") ] in
  match Ribosome_server_lib.Ui_protocol.decode_message json with
  | Ok _ -> Alcotest.fail "expected error for unknown kind"
  | Error e ->
      Alcotest.(check bool)
        "error mentions unknown" true
        (string_contains e "unknown")

let test_version () =
  Alcotest.(check string)
    "version constant" "0.0.0" Ribosome_server_lib.Ui_protocol.version

let () =
  Alcotest.run "ribosome-ui-protocol"
    [
      ( "fixtures",
        [
          Alcotest.test_case "attach" `Quick test_attach;
          Alcotest.test_case "component_event_click" `Quick
            test_component_event_click;
          Alcotest.test_case "component_event_change" `Quick
            test_component_event_change;
          Alcotest.test_case "cancel" `Quick test_cancel;
          Alcotest.test_case "disconnect" `Quick test_disconnect;
          Alcotest.test_case "session_state" `Quick test_session_state;
          Alcotest.test_case "template_update" `Quick test_template_update;
          Alcotest.test_case "generation_started" `Quick test_generation_started;
          Alcotest.test_case "generation_delta" `Quick test_generation_delta;
          Alcotest.test_case "generation_completed" `Quick
            test_generation_completed;
          Alcotest.test_case "generation_failed" `Quick test_generation_failed;
          Alcotest.test_case "event_rejection_stale" `Quick
            test_event_rejection_stale;
          Alcotest.test_case "event_rejection_duplicate" `Quick
            test_event_rejection_duplicate;
        ] );
      ("errors", [ Alcotest.test_case "unknown kind" `Quick test_unknown_kind ]);
      ("meta", [ Alcotest.test_case "version" `Quick test_version ]);
    ]
