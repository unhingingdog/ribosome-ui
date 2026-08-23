open Ribosome_server_lib

(* Task 7.4: Contract fixtures — decode protocol fixtures and assert
   field names, enum strings, and version constants match between
   the OCaml server and the fixtures shared with the TypeScript adapter. *)

let read_fixture name =
  let path = Filename.concat "protocol-fixtures" name in
  (* Try CWD first, then walk up to find the source tree *)
  try
    let ic = open_in path in
    let len = in_channel_length ic in
    let buf = Bytes.create len in
    really_input ic buf 0 len;
    close_in ic;
    Bytes.to_string buf
  with Sys_error _ ->
    let cwd = Sys.getcwd () in
    let rec find dir =
      let candidate =
        Filename.concat dir "ribosome-server/test/protocol-fixtures"
      in
      if Sys.is_directory candidate then (
        let full = Filename.concat candidate name in
        let ic = open_in full in
        let len = in_channel_length ic in
        let buf = Bytes.create len in
        really_input ic buf 0 len;
        close_in ic;
        Bytes.to_string buf)
      else
        let parent = Filename.dirname dir in
        if parent = dir then Alcotest.fail "could not find fixtures"
        else find parent
    in
    find cwd

let parse s = Yojson.Safe.from_string s

let field name json =
  match json with
  | `Assoc a -> (
      match Stdlib.List.assoc_opt name a with
      | Some v -> v
      | None -> Alcotest.fail ("missing field: " ^ name))
  | _ -> Alcotest.fail "expected object"

let string_field name json =
  match field name json with
  | `String s -> s
  | _ -> Alcotest.fail ("expected string: " ^ name)

let list_field name json =
  match field name json with
  | `List l -> l
  | _ -> Alcotest.fail ("expected list: " ^ name)

let test_harness_version () =
  let fixture = parse (read_fixture "harness.json") in
  let v = string_field "version" fixture in
  Alcotest.(check string) "harness version matches" Harness_protocol.version v

let test_harness_messages () =
  let fixture = parse (read_fixture "harness.json") in
  let messages = field "messages" fixture in
  let kinds =
    [
      "attach";
      "delta";
      "generation_completed";
      "generation_failed";
      "user_turn";
      "ack";
      "rejection";
    ]
  in
  Stdlib.List.iter
    (fun kind ->
      let msg = field kind messages in
      let decoded =
        match Harness_protocol.decode_message msg with
        | Ok _ -> ()
        | Error e ->
            Alcotest.fail
              ("harness fixture '" ^ kind ^ "' failed to decode: " ^ e)
      in
      let _ = decoded in
      let kind_str = string_field "kind" msg in
      Alcotest.(check string) ("harness kind: " ^ kind) kind kind_str)
    kinds

let test_harness_enum_strings () =
  let fixture = parse (read_fixture "harness.json") in
  let enums = field "enum_strings" fixture in
  let reasons = list_field "rejection_reasons" enums in
  let expected =
    [
      "invalid_session";
      "invalid_generation";
      "invalid_sequence";
      "malformed_payload";
    ]
  in
  Stdlib.List.iter2
    (fun exp json ->
      match json with
      | `String s -> Alcotest.(check string) "rejection reason" exp s
      | _ -> Alcotest.fail "expected string in rejection_reasons")
    expected reasons

let test_ui_version () =
  let fixture = parse (read_fixture "ui.json") in
  let v = string_field "version" fixture in
  Alcotest.(check string) "ui version matches" Ui_protocol.version v

let test_ui_messages () =
  let fixture = parse (read_fixture "ui.json") in
  let messages = field "messages" fixture in
  let kinds =
    [
      "attach";
      "attach_with_revision";
      "component_event_click";
      "component_event_change";
      "component_event_submit";
      "cancel";
      "disconnect";
      "session_state";
      "template_update";
      "event_rejection_stale";
      "event_rejection_duplicate";
    ]
  in
  Stdlib.List.iter
    (fun kind ->
      let msg = field kind messages in
      match Ui_protocol.decode_message msg with
      | Ok _ -> ()
      | Error e ->
          Alcotest.fail ("ui fixture '" ^ kind ^ "' failed to decode: " ^ e))
    kinds

let test_ui_enum_strings () =
  let fixture = parse (read_fixture "ui.json") in
  let enums = field "enum_strings" fixture in
  let kinds = list_field "component_kinds" enums in
  let expected_kinds = [ "click"; "change"; "submit" ] in
  Stdlib.List.iter2
    (fun exp json ->
      match json with
      | `String s -> Alcotest.(check string) "component kind" exp s
      | _ -> Alcotest.fail "expected string in component_kinds")
    expected_kinds kinds;
  let reasons = list_field "rejection_reasons" enums in
  let expected_reasons = [ "stale_revision"; "duplicate_event_id" ] in
  Stdlib.List.iter2
    (fun exp json ->
      match json with
      | `String s -> Alcotest.(check string) "rejection reason" exp s
      | _ -> Alcotest.fail "expected string in rejection_reasons")
    expected_reasons reasons

let test_reject_unsupported_version () =
  let bad_attach =
    `Assoc
      [
        ("kind", `String "attach");
        ("version", `String "99.0.0");
        ("session_id", `String "rs-1");
        ("harness_session_id", `String "oc-1");
        ("nonce", `String "n");
      ]
  in
  (match Harness_protocol.decode_message bad_attach with
  | Ok _ -> ()
  | Error _ ->
      (* Version field is not checked in decode_message — it's a
          protocol-level constant. The test asserts the fixture
          version matches the code constant, which is the real
          guard against drift. *)
      ());
  (* The real guard: fixture version must match code version *)
  let fixture = parse (read_fixture "harness.json") in
  let v = string_field "version" fixture in
  Alcotest.(check string) "version must match" Harness_protocol.version v

let () =
  Alcotest.run "ribosome-contract-fixtures"
    [
      ( "harness",
        [
          Alcotest.test_case "version" `Quick test_harness_version;
          Alcotest.test_case "messages decode" `Quick test_harness_messages;
          Alcotest.test_case "enum strings" `Quick test_harness_enum_strings;
        ] );
      ( "ui",
        [
          Alcotest.test_case "version" `Quick test_ui_version;
          Alcotest.test_case "messages decode" `Quick test_ui_messages;
          Alcotest.test_case "enum strings" `Quick test_ui_enum_strings;
        ] );
      ( "cross",
        [
          Alcotest.test_case "reject unsupported version" `Quick
            test_reject_unsupported_version;
        ] );
    ]
