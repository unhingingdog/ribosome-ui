(* Deterministic Telomere balancer coverage, ported from the former JS suites.

   The balancer is private; all behavior is tested through the public
   Processor API. Completion cases assert the exact suffix string. *)

open Test_support

(* --- Already complete input --- *)

let already_complete_tests =
  [
    completion_case ("complete flat object", "{\"a\":1}", "");
    completion_case ("complete flat array", "[1,2,3]", "");
    completion_case ("complete nested", "{\"a\":{\"b\":2}}", "");
    completion_case ("empty object", "{}", "");
    completion_case ("empty array", "[]", "");
    completion_case ("array of objects complete", "[{\"a\":1},{\"b\":2}]", "");
    completion_case
      ("string with escaped quote", "{\"a\":\"say \\\"hi\\\"\"}", "");
    completion_case ("string with backslash", "{\"a\":\"hel\\\\lo\"}", "");
    completion_case ("empty input", "", "");
    completion_case ("whitespace only", "   ", "");
  ]

(* --- Partial input completions --- *)

let partial_completion_tests =
  [
    completion_case ("unclosed object", "{\"key\":\"val\"", "}");
    completion_case ("nested unclosed", "{\"a\":{\"b\":1", "}}");
    completion_case ("unclosed array", "[1,2", "]");
    completion_case ("unclosed array in object", "{\"items\":[1,2", "]}");
    completion_case ("deeply nested", "{\"a\":[{\"b\":[1", "]}]}");
    completion_case ("open string value", "{\"key\":\"val", "\"}");
    completion_case ("complete boolean value", "{\"flag\":true", "}");
    completion_case ("complete null value", "{\"x\":null", "}");
    completion_case ("partial number value", "{\"n\":42", "}");
  ]

(* --- Not yet closable (Pending) --- *)

let pending_tests =
  [
    pending_case ("partial boolean tru", "{\"flag\":tru");
    pending_case ("partial null nul", "{\"x\":nul");
    pending_case ("after colon", "{\"key\":");
    pending_case ("dangling comma in object", "{\"a\":1,");
    pending_case ("dangling comma in array", "[1,");
    pending_case ("trailing exponent 1e", "{\"a\":1e");
    pending_case ("trailing minus", "{\"a\":-");
    pending_case ("trailing decimal", "{\"a\":1.");
    pending_case ("mid-key", "{\"ke");
    pending_case ("backslash in key", "{\"ke\\");
    pending_case ("key closed no colon", "{\"key\"");
    pending_case ("backslash in value", "{\"a\":\"hel\\");
    pending_case ("mid-key nested", "{\"a\":{\"ke");
    pending_case ("trailing exponent in array", "[1e");
    pending_case ("unicode escape partial", "{\"a\":\"\\u");
  ]

(* --- Corrupted input --- *)

let corrupted_tests =
  [
    corrupted_case ("mismatched close bracket in obj", "{\"a\":1]");
    corrupted_case ("close brace on empty stack", "}");
    corrupted_case ("close bracket on empty stack", "]");
    corrupted_case ("invalid character", "{\"a\":$}");
    corrupted_case ("close brace in array", "[}");
    corrupted_case ("unexpected comma start array", "[,");
    corrupted_case ("unexpected comma start object", "{,");
    corrupted_case ("unexpected colon at top level", ":");
    corrupted_case ("comma then brace", "{\"a\":1,}");
    corrupted_case ("trailing comma then close array", "[1,]");
    corrupted_case ("after string non-delimiter obj", "{\"a\":\"x\"1");
    corrupted_case ("after string non-delimiter arr", "[\"x\"1");
    corrupted_case ("unquoted key", "{a");
    corrupted_case ("unexpected open bracket in key", "{[");
    corrupted_case ("toplevel number not allowed", "1");
    corrupted_case ("toplevel quote not allowed", "\"");
  ]

let test_poisoned_state_fast_paths () =
  let state = Telomere.Processor.create_processor () in
  let output1, state1 = Telomere.Processor.feed state "{\"a\":1]" in
  (match output1 with
  | Telomere.Processor.Corrupted -> ()
  | _ -> Alcotest.fail "expected first feed to be Corrupted");
  let output2, _ = Telomere.Processor.feed state1 "{\"b\":2}" in
  match output2 with
  | Telomere.Processor.Corrupted -> ()
  | _ -> Alcotest.fail "expected poisoned state to fast-path Corrupted"

(* --- Brace states --- *)

let brace_state_tests =
  [
    completion_case ("Brace Empty just brace", "{", "}");
    completion_case ("Brace InValue String Open", "{\"a\":\"hel", "\"}");
    completion_case ("Brace InValue String Closed", "{\"a\":\"hello\"", "}");
    completion_case ("Brace InValue NonString number", "{\"a\":42", "}");
    completion_case ("Brace InValue NonString float", "{\"a\":1.5", "}");
    completion_case ("Brace InValue NonString negative", "{\"a\":-3", "}");
    completion_case ("Brace InValue NonString scientific", "{\"a\":1e5", "}");
    completion_case ("Brace InValue NonString true", "{\"a\":true", "}");
    completion_case ("Brace InValue NonString false", "{\"a\":false", "}");
    completion_case ("Brace InValue NonString null", "{\"a\":null", "}");
    completion_case ("Brace NestedValueComplete obj", "{\"a\":{\"b\":1}", "}");
    completion_case ("Brace NestedValueComplete arr", "{\"a\":[1,2]", "}");
  ]

(* --- Bracket states --- *)

let bracket_state_tests =
  [
    completion_case ("Bracket Empty just bracket", "[", "]");
    completion_case ("Bracket InValue String Open", "[\"hel", "\"]");
    completion_case ("Bracket InValue String Closed", "[\"hello\"", "]");
    completion_case ("Bracket InValue NonString number", "[42", "]");
    completion_case ("Bracket InValue NonString true", "[true", "]");
    completion_case ("Bracket NestedValueComplete obj", "[{\"a\":1}", "]");
    completion_case ("Bracket NestedValueComplete arr", "[[1,2]", "]");
  ]

(* --- Closing stack depth --- *)

let stack_depth_tests =
  [
    completion_case ("2 levels obj in arr", "[{\"a\":1", "}]");
    completion_case ("2 levels arr in obj", "{\"a\":[1", "]}");
    completion_case
      ("4 levels deeply nested", "{\"a\":{\"b\":{\"c\":{\"d\":1", "}}}}");
    completion_case ("open string value nested", "{\"a\":{\"b\":\"hel", "\"}}");
  ]

(* --- Streaming across chunk boundaries --- *)

let test_key_split () =
  let state = Telomere.Processor.create_processor () in
  let _, s1 = Telomere.Processor.feed state "{\"ke" in
  let output, _ = Telomere.Processor.feed s1 "y\":1}" in
  match output with
  | Telomere.Processor.Completion "" -> ()
  | Telomere.Processor.Completion s ->
      Alcotest.fail ("expected empty completion, got " ^ s)
  | Pending -> Alcotest.fail "expected Completion, got Pending"
  | Corrupted -> Alcotest.fail "expected Completion, got Corrupted"

let test_value_split () =
  let state = Telomere.Processor.create_processor () in
  let _, s1 = Telomere.Processor.feed state "{\"a\":tr" in
  let output, _ = Telomere.Processor.feed s1 "ue}" in
  match output with
  | Telomere.Processor.Completion "" -> ()
  | _ -> Alcotest.fail "expected Completion \"\""

let test_string_value_split () =
  let state = Telomere.Processor.create_processor () in
  let _, s1 = Telomere.Processor.feed state "{\"a\":\"hel" in
  let output, _ = Telomere.Processor.feed s1 "lo\"" in
  match output with
  | Telomere.Processor.Completion "}" -> ()
  | _ -> Alcotest.fail "expected Completion \"}\""

let test_escape_split () =
  let state = Telomere.Processor.create_processor () in
  let _, s1 = Telomere.Processor.feed state "{\"a\":\"hel\\" in
  let output, _ = Telomere.Processor.feed s1 "lo\"" in
  match output with
  | Telomere.Processor.Completion "}" -> ()
  | _ -> Alcotest.fail "expected Completion \"}\""

let full_template =
  "{\"kind\":\"container\",\"id\":\"root-1\",\"count\":3,\"enabled\":true,\"ratio\":1.5,\"label\":null,\"title\":\"Hello \
   world\",\"children\":[{\"kind\":\"text\",\"id\":\"t1\",\"content\":\"line \
   one\"},{\"kind\":\"image\",\"id\":\"img-1\",\"src\":\"/a.png\",\"alt\":\"an \
   image\"},{\"kind\":\"input\",\"id\":\"inp-1\",\"value\":42}]}"

let test_full_template_streamed () =
  let chunk_size = 10 in
  let state = ref (Telomere.Processor.create_processor ()) in
  let last = ref None in
  let i = ref 0 in
  while !i < String.length full_template do
    let chunk =
      String.sub full_template !i
        (min chunk_size (String.length full_template - !i))
    in
    let output, s = Telomere.Processor.feed !state chunk in
    state := s;
    (match output with
    | Telomere.Processor.Completion c -> last := Some c
    | _ -> ());
    i := !i + chunk_size
  done;
  match !last with
  | Some "" -> ()
  | Some s -> Alcotest.fail ("expected empty final completion, got " ^ s)
  | None -> Alcotest.fail "expected a completion, got none"

let streaming_tests =
  [
    Alcotest.test_case "key split across chunks" `Quick test_key_split;
    Alcotest.test_case "value split across chunks" `Quick test_value_split;
    Alcotest.test_case "string value split across chunks" `Quick
      test_string_value_split;
    Alcotest.test_case "escape split at chunk boundary" `Quick test_escape_split;
    Alcotest.test_case "full template streamed in 10-char chunks" `Quick
      test_full_template_streamed;
  ]

(* --- Multi-delta cases (ported from Rust balancing_test_data.rs) --- *)

let multi_delta_completion_tests =
  [
    completion_deltas_case ("empty array delta", [ "[" ], "]");
    completion_deltas_case ("empty object delta", [ "{" ], "}");
    completion_deltas_case ("array one number", [ "["; "1" ], "]");
    completion_deltas_case ("array one closable literal", [ "["; "true" ], "]");
    completion_deltas_case ("object simple kv", [ "{"; "\"a\""; ":"; "1" ], "}");
    completion_deltas_case
      ("nested object in array", [ "["; "{"; "\"k\""; ":"; "\"v\"" ], "}]");
    completion_deltas_case
      ("double nest", [ "{"; "\"a\""; ":"; "["; "{"; "\"b\""; ":"; "2" ], "}]}");
    completion_deltas_case
      ( "multi kv object",
        [ "{"; "\"a\""; ":"; "1"; ","; "\"b\""; ":"; "2" ],
        "}" );
    completion_deltas_case
      ("trailing string value", [ "{"; "\"a\""; ":"; "\"x\"" ], "}");
    completion_deltas_case
      ( "array of objects partial second",
        [ "["; "{"; "\"a\""; ":"; "1"; "}"; ","; "{"; "\"b\""; ":"; "2" ],
        "}]" );
    completion_deltas_case
      ("obj value array partial", [ "{"; "\"a\""; ":"; "["; "1" ], "]}");
    completion_deltas_case
      ("nested arrays need two brackets", [ "["; "["; "1" ], "]]");
    completion_deltas_case ("array one string open", [ "["; "\"hel" ], "\"]");
    completion_deltas_case
      ("obj in open string value", [ "{"; "\"a\""; ":"; "\"va" ], "\"}");
    completion_deltas_case
      ( "obj escaped quote then closable",
        [ "{"; "\"a\""; ":"; "\""; "\\"; "\"" ],
        "\"}" );
    completion_deltas_case
      ("array string escaped then closable", [ "["; "\""; "\\"; "\"" ], "\"]");
    completion_deltas_case
      ( "trailing ws after obj value",
        [ "{"; "\"a\""; ":"; "\"x\""; " "; "\t" ],
        "}" );
    completion_deltas_case
      ("trailing ws after array value", [ "["; "\"x\""; " "; "\n" ], "]");
    completion_deltas_case
      ("close before key (empty obj split)", [ "{"; "}" ], "");
    completion_deltas_case ("already complete empty array", [ "[]" ], "");
    completion_deltas_case
      ("already complete simple object", [ "{\"a\":1}" ], "");
    completion_deltas_case
      ("already complete object then ws", [ "{\"a\":1}"; "  " ], "");
    completion_deltas_case ("already complete array then ws", [ "[]"; "\n" ], "");
    completion_deltas_case
      ("messy chunk split keyword", [ "[t"; "ru"; "e" ], "]");
    completion_deltas_case
      ("messy chunk split escape", [ "[\"\\"; "\"abc" ], "\"]");
  ]

let multi_delta_pending_tests =
  [
    pending_deltas_case ("obj expecting colon", [ "{"; "\"a\"" ]);
    pending_deltas_case ("obj expecting value", [ "{"; "\"a\""; ":" ]);
    pending_deltas_case ("obj in open string key", [ "{"; "\"ke" ]);
    pending_deltas_case ("obj in escape", [ "{"; "\"a\""; ":"; "\"va\\" ]);
    pending_deltas_case ("array in escape", [ "["; "\""; "\\" ]);
    pending_deltas_case
      ("array after comma expecting value", [ "["; "1"; ","; "" ]);
    pending_deltas_case ("number partial minus", [ "{"; "\"n\""; ":"; "-" ]);
    pending_deltas_case ("number partial exp", [ "{"; "\"n\""; ":"; "1e" ]);
    pending_deltas_case ("number partial decimal", [ "{"; "\"n\""; ":"; "1." ]);
    pending_deltas_case ("literal true partial", [ "["; "tr" ]);
    pending_deltas_case ("literal null partial", [ "{"; "\"x\""; ":"; "nu" ]);
    pending_deltas_case
      ("unicode escape partial deltas", [ "{"; "\"a\""; ":"; "\""; "\\"; "u" ]);
  ]

let multi_delta_corrupted_tests =
  [
    corrupted_deltas_case ("corrupted mismatch", [ "["; "]"; "]" ]);
    corrupted_deltas_case ("corrupted close brace in array", [ "["; "}" ]);
    corrupted_deltas_case
      ("corrupted unexpected comma start array", [ "["; "," ]);
    corrupted_deltas_case
      ("corrupted unexpected comma start object", [ "{"; "," ]);
    corrupted_deltas_case ("corrupted unexpected colon top", [ ":" ]);
    corrupted_deltas_case
      ("corrupted quote in nonstring data", [ "["; "1"; "\""; "]" ]);
    corrupted_deltas_case
      ("corrupted comma then brace", [ "{"; "\"a\""; ":"; "1"; ","; "}" ]);
    corrupted_deltas_case
      ("array trailing comma then close", [ "["; "1"; ","; "]" ]);
    corrupted_deltas_case ("toplevel close brace", [ "}" ]);
    corrupted_deltas_case ("toplevel close bracket", [ "]" ]);
    corrupted_deltas_case ("object close bracket mismatch", [ "{"; "]" ]);
    corrupted_deltas_case
      ("obj after string non-delimiter", [ "{"; "\"a\""; ":"; "\"x\""; "1" ]);
    corrupted_deltas_case
      ("array after string non-delimiter", [ "["; "\"x\""; "1" ]);
    corrupted_deltas_case ("unquoted key is corrupted", [ "{"; "a" ]);
    corrupted_deltas_case ("unexpected open bracket in key", [ "{"; "[" ]);
    corrupted_deltas_case ("toplevel number not allowed", [ "1" ]);
    corrupted_deltas_case ("toplevel quote not allowed", [ "\"" ]);
    corrupted_deltas_case ("trailing content after array", [ "[1, 2]"; "3" ]);
    corrupted_deltas_case ("trailing content after object", [ "{\"a\":1}"; "x" ]);
  ]

(* --- Regression test (ported from Rust regression.rs) --- *)

let test_regression_close_object_as_last_item_in_array () =
  let initial_chunk =
    "{ \"type\": \"container\", \"children\": [ { \"type\": \"heading\", \
     \"level\": 2, \"content\": \"Let's get started\" }, { \"type\": \
     \"paragraph\", \"content\": \"Hi! Please provide your name and what you \
     need help with.\" }, { \"type\": \"form\", \"children\": [ { \"type\": \
     \"input\", \"queryId\": \"user_name\", \"queryContent\": \"Your name\" }, \
     { \"type\": \"input\", \"queryId\": \"user_need\", \"queryContent\": \
     \"What do you need help with?\" } ] "
  in
  let state = Telomere.Processor.create_processor () in
  let _, s1 = Telomere.Processor.feed state initial_chunk in
  let output, _ = Telomere.Processor.feed s1 "}" in
  match output with
  | Telomere.Processor.Completion "]}" -> ()
  | Telomere.Processor.Completion s ->
      Alcotest.fail ("expected \"]}\", got " ^ s)
  | Pending -> Alcotest.fail "expected Completion, got Pending"
  | Corrupted -> Alcotest.fail "expected Completion, got Corrupted"

(* --- Deep nesting (ported from Rust perf.rs, without timing) --- *)

let generate_deeply_nested_json depth =
  let payload =
    "\"int\":1,\"literal\":true,\"escape\":\"\\\\\",\"arr\":[null]"
  in
  let buf = Buffer.create (depth * 80) in
  for i = 0 to depth - 1 do
    Buffer.add_char buf '{';
    Buffer.add_string buf payload;
    if i < depth - 1 then Buffer.add_string buf ",\"next\":"
  done;
  let expected = String.make depth '}' in
  (Buffer.contents buf, expected)

let test_deeply_nested_5 () =
  let json, expected = generate_deeply_nested_json 5 in
  assert_feed "5 levels" json (Completion expected)

let test_deeply_nested_100 () =
  let json, expected = generate_deeply_nested_json 100 in
  assert_feed "100 levels" json (Completion expected)

let test_deeply_nested_1000 () =
  let json, expected = generate_deeply_nested_json 1000 in
  assert_feed "1000 levels" json (Completion expected)

let deep_nesting_tests =
  [
    Alcotest.test_case "5 levels" `Quick test_deeply_nested_5;
    Alcotest.test_case "100 levels" `Quick test_deeply_nested_100;
    Alcotest.test_case "1000 levels" `Quick test_deeply_nested_1000;
  ]

let () =
  Alcotest.run "telomere-balancer"
    [
      ("already complete", already_complete_tests);
      ("partial completions", partial_completion_tests);
      ("not yet closable", pending_tests);
      ( "corrupted",
        corrupted_tests
        @ [
            Alcotest.test_case "poisoned state fast-paths" `Quick
              test_poisoned_state_fast_paths;
          ] );
      ("brace states", brace_state_tests);
      ("bracket states", bracket_state_tests);
      ("stack depth", stack_depth_tests);
      ("streaming", streaming_tests);
      ("multi-delta completions", multi_delta_completion_tests);
      ("multi-delta pending", multi_delta_pending_tests);
      ("multi-delta corrupted", multi_delta_corrupted_tests);
      ( "regression & deep nesting",
        [
          Alcotest.test_case "close object as last item in array" `Quick
            test_regression_close_object_as_last_item_in_array;
        ]
        @ deep_nesting_tests );
    ]
