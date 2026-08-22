(* Smoke test: proves Dune discovers the Telomere suite and the processor
   returns the expected output kinds. Full coverage lands in Tasks 2.2 and
   2.3. *)

let test_complete_object () =
  let open Telomere.Processor in
  let state = create_processor () in
  let output, _ = feed state "{}" in
  match output with
  | Completion _ -> ()
  | Pending -> Alcotest.fail "expected Completion, got Pending"
  | Corrupted -> Alcotest.fail "expected Completion, got Corrupted"

let test_partial_object_completion_suffix () =
  let open Telomere.Processor in
  let state = create_processor () in
  let output, _ = feed state "{\"name\":\"Alice\"" in
  match output with
  | Completion suffix ->
      Alcotest.(check string) "suffix closes object" "}" suffix
  | Pending -> Alcotest.fail "expected Completion, got Pending"
  | Corrupted -> Alcotest.fail "expected Completion, got Corrupted"

let test_mid_value_pending () =
  let open Telomere.Processor in
  let state = create_processor () in
  let output, _ = feed state "{\"k\":" in
  match output with
  | Pending -> ()
  | Completion _ -> Alcotest.fail "expected Pending, got Completion"
  | Corrupted -> Alcotest.fail "expected Pending, got Corrupted"

let () =
  Alcotest.run "telomere-smoke"
    [
      ( "smoke",
        [
          Alcotest.test_case "complete object" `Quick test_complete_object;
          Alcotest.test_case "partial object completion suffix" `Quick
            test_partial_object_completion_suffix;
          Alcotest.test_case "mid value pending" `Quick test_mid_value_pending;
        ] );
    ]
