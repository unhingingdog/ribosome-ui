(* Shared helpers for readable Telomere test assertions.

   The balancer is private to the telomere library; all balancer behavior is
   observable through the public Processor API:
     - Balancer Ok (suffix, state)    -> Completion suffix
     - Balancer Error (NotClosable, _) -> Pending
     - Balancer Error (_, corrupted)   -> Corrupted *)

type expected = Completion of string | Pending | Corrupted

(* A single table-driven case: feed [input] to a fresh processor and assert
   the output matches [expected]. *)
let assert_feed (label : string) (input : string) (expected : expected) =
  let state = Telomere.Processor.create_processor () in
  let output, _ = Telomere.Processor.feed state input in
  match (expected, output) with
  | Completion exp, Telomere.Processor.Completion actual ->
      Alcotest.(check string) label exp actual
  | Pending, Telomere.Processor.Pending -> ()
  | Corrupted, Telomere.Processor.Corrupted -> ()
  | Completion _, Telomere.Processor.Pending ->
      Alcotest.fail (label ^ ": expected Completion, got Pending")
  | Completion _, Telomere.Processor.Corrupted ->
      Alcotest.fail (label ^ ": expected Completion, got Corrupted")
  | Pending, Telomere.Processor.Completion _ ->
      Alcotest.fail (label ^ ": expected Pending, got Completion")
  | Pending, Telomere.Processor.Corrupted ->
      Alcotest.fail (label ^ ": expected Pending, got Corrupted")
  | Corrupted, Telomere.Processor.Completion _ ->
      Alcotest.fail (label ^ ": expected Corrupted, got Completion")
  | Corrupted, Telomere.Processor.Pending ->
      Alcotest.fail (label ^ ": expected Corrupted, got Pending")

(* Build an Alcotest quick test case from a single-chunk table entry. *)
let completion_case (label, input, suffix) =
  Alcotest.test_case label `Quick (fun () ->
      assert_feed label input (Completion suffix))

let pending_case (label, input) =
  Alcotest.test_case label `Quick (fun () -> assert_feed label input Pending)

let corrupted_case (label, input) =
  Alcotest.test_case label `Quick (fun () -> assert_feed label input Corrupted)

(* Feed a list of chunks to a fresh processor, threading state, and return
   the output from the last chunk. *)
let feed_deltas (chunks : string list) : Telomere.Processor.output =
  let state = Telomere.Processor.create_processor () in
  let final_output, _ =
    List.fold_left
      (fun (_, state) chunk ->
        let output, state = Telomere.Processor.feed state chunk in
        (output, state))
      (Telomere.Processor.Pending, state)
      chunks
  in
  final_output

(* Assert that feeding [chunks] produces [expected] on the last delta. *)
let assert_feed_deltas (label : string) (chunks : string list)
    (expected : expected) =
  let output = feed_deltas chunks in
  match (expected, output) with
  | Completion exp, Telomere.Processor.Completion actual ->
      Alcotest.(check string) label exp actual
  | Pending, Telomere.Processor.Pending -> ()
  | Corrupted, Telomere.Processor.Corrupted -> ()
  | Completion _, Telomere.Processor.Pending ->
      Alcotest.fail (label ^ ": expected Completion, got Pending")
  | Completion _, Telomere.Processor.Corrupted ->
      Alcotest.fail (label ^ ": expected Completion, got Corrupted")
  | Pending, Telomere.Processor.Completion _ ->
      Alcotest.fail (label ^ ": expected Pending, got Completion")
  | Pending, Telomere.Processor.Corrupted ->
      Alcotest.fail (label ^ ": expected Pending, got Corrupted")
  | Corrupted, Telomere.Processor.Completion _ ->
      Alcotest.fail (label ^ ": expected Corrupted, got Completion")
  | Corrupted, Telomere.Processor.Pending ->
      Alcotest.fail (label ^ ": expected Corrupted, got Pending")

(* Build an Alcotest quick test case from a multi-delta table entry. *)
let completion_deltas_case (label, deltas, suffix) =
  Alcotest.test_case label `Quick (fun () ->
      assert_feed_deltas label deltas (Completion suffix))

let pending_deltas_case (label, deltas) =
  Alcotest.test_case label `Quick (fun () ->
      assert_feed_deltas label deltas Pending)

let corrupted_deltas_case (label, deltas) =
  Alcotest.test_case label `Quick (fun () ->
      assert_feed_deltas label deltas Corrupted)
