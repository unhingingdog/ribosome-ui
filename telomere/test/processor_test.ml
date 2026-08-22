(* Processor-specific tests: buffer accumulation, completion shrinking, and
   corrupted-state persistence. Ported from the former JS processor suite. *)

let check_completion label expected output =
  match output with
  | Telomere.Processor.Completion actual ->
      Alcotest.(check string) label expected actual
  | Pending -> Alcotest.fail (label ^ ": expected Completion, got Pending")
  | Corrupted -> Alcotest.fail (label ^ ": expected Completion, got Corrupted")

let test_completion_once_string_capped () =
  let state = Telomere.Processor.create_processor () in
  let out1, s1 = Telomere.Processor.feed state "{\"key\":" in
  (match out1 with
  | Pending -> ()
  | _ -> Alcotest.fail "expected Pending after colon");
  let out2, _ = Telomere.Processor.feed s1 "\"val" in
  check_completion "close string and object" "\"}" out2

let test_completion_shrinks () =
  let state = Telomere.Processor.create_processor () in
  let out1, s1 = Telomere.Processor.feed state "{\"a\":[" in
  check_completion "open array in object" "]}" out1;
  let out2, s2 = Telomere.Processor.feed s1 "{\"b\":1" in
  check_completion "open object in array in object" "}]}" out2;
  let out3, s3 = Telomere.Processor.feed s2 "}" in
  check_completion "inner object closed" "]}" out3;
  let out4, _ = Telomere.Processor.feed s3 "]" in
  check_completion "array closed" "}" out4

let test_corrupted_poisons_subsequent () =
  let state = Telomere.Processor.create_processor () in
  let _, s1 = Telomere.Processor.feed state "{\"a\":1" in
  let out2, s2 = Telomere.Processor.feed s1 "]" in
  (match out2 with
  | Telomere.Processor.Corrupted -> ()
  | _ -> Alcotest.fail "expected Corrupted on mismatched bracket");
  let out3, _ = Telomere.Processor.feed s2 "{\"b\":2}" in
  match out3 with
  | Telomere.Processor.Corrupted -> ()
  | _ -> Alcotest.fail "expected poisoned state to fast-path Corrupted"

let test_complete_well_formed () =
  let state = Telomere.Processor.create_processor () in
  let _, s1 = Telomere.Processor.feed state "{\"name\"" in
  let _, s2 = Telomere.Processor.feed s1 ":\"Alice\"" in
  let out3, _ = Telomere.Processor.feed s2 "}" in
  check_completion "empty completion for complete object" "" out3

let () =
  Alcotest.run "telomere-processor"
    [
      ( "processor",
        [
          Alcotest.test_case "completion once string capped" `Quick
            test_completion_once_string_capped;
          Alcotest.test_case "completion shrinks as structure arrives" `Quick
            test_completion_shrinks;
          Alcotest.test_case "corrupted poisons subsequent feeds" `Quick
            test_corrupted_poisons_subsequent;
          Alcotest.test_case "complete well-formed object" `Quick
            test_complete_well_formed;
        ] );
    ]
