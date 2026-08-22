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
  | json -> Ribosome_server_lib.Harness_protocol.decode_message json
  | exception Yojson.Json_error msg -> Error ("json parse error: " ^ msg)

let roundtrip name expected =
  let json_str = read_fixture name in
  let decoded = decode json_str in
  Alcotest.(check (result string string))
    ("decode " ^ name) (Ok "decoded")
    (Result.map (fun _ -> "decoded") decoded);
  let encoded =
    match decoded with
    | Ok msg -> Ribosome_server_lib.Harness_protocol.encode_message msg
    | Error e -> Alcotest.fail ("decode failed: " ^ e)
  in
  let redecoded = Ribosome_server_lib.Harness_protocol.decode_message encoded in
  Alcotest.(check (result string string))
    ("roundtrip " ^ name)
    (Result.map (fun _ -> "decoded") decoded)
    (Result.map (fun _ -> "decoded") redecoded);
  Alcotest.(check (result string string))
    ("roundtrip stable " ^ name)
    (Ok expected)
    (Result.map (fun _ -> expected) redecoded)

let test_attach () = roundtrip "harness_attach" "attach"
let test_delta () = roundtrip "harness_delta" "delta"

let test_generation_completed () =
  roundtrip "harness_generation_completed" "generation_completed"

let test_generation_failed () =
  roundtrip "harness_generation_failed" "generation_failed"

let test_user_turn () = roundtrip "harness_user_turn" "user_turn"
let test_ack () = roundtrip "harness_ack" "ack"
let test_rejection () = roundtrip "harness_rejection" "rejection"

let string_contains haystack needle =
  let rec search i =
    if i > String.length haystack - String.length needle then false
    else if String.sub haystack i (String.length needle) = needle then true
    else search (i + 1)
  in
  search 0

let test_unknown_kind () =
  let json = `Assoc [ ("kind", `String "unknown") ] in
  match Ribosome_server_lib.Harness_protocol.decode_message json with
  | Ok _ -> Alcotest.fail "expected error for unknown kind"
  | Error e ->
      Alcotest.(check bool)
        "error mentions unknown" true
        (string_contains e "unknown")

let test_version () =
  Alcotest.(check string)
    "version constant" "0.0.0" Ribosome_server_lib.Harness_protocol.version

let () =
  Alcotest.run "ribosome-harness-protocol"
    [
      ( "fixtures",
        [
          Alcotest.test_case "attach" `Quick test_attach;
          Alcotest.test_case "delta" `Quick test_delta;
          Alcotest.test_case "generation_completed" `Quick
            test_generation_completed;
          Alcotest.test_case "generation_failed" `Quick test_generation_failed;
          Alcotest.test_case "user_turn" `Quick test_user_turn;
          Alcotest.test_case "ack" `Quick test_ack;
          Alcotest.test_case "rejection" `Quick test_rejection;
        ] );
      ("errors", [ Alcotest.test_case "unknown kind" `Quick test_unknown_kind ]);
      ("meta", [ Alcotest.test_case "version" `Quick test_version ]);
    ]
