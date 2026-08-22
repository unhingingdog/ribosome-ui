open Ribosome.Template

let text id value = Text Text.{ id; text_type = Paragraph; value }

let feed_delta_seq session gen_id seqs delta =
  Ribosome.Session.feed_delta session ~gen_id ~seq:seqs ~delta

(* --- create --- *)

let test_create () =
  let session = Ribosome.Session.create ~id:"s1" ~mode:Ribosome.Mode.ui in
  Alcotest.(check string) "session id" "s1" session.id;
  Alcotest.(check int) "revision 0" 0 session.revision;
  Alcotest.(check (option pass)) "tree None" None session.tree;
  Alcotest.(check (option pass)) "generation None" None session.generation

(* --- start generation --- *)

let test_start_generation () =
  let session = Ribosome.Session.create ~id:"s1" ~mode:Ribosome.Mode.ui in
  match Ribosome.Session.start_generation session ~gen_id:"g1" with
  | Ok s -> (
      match s.generation with
      | Some g ->
          Alcotest.(check string) "generation id" "g1" g.id;
          Alcotest.(check int) "seq 0" 0 g.next_seq
      | None -> Alcotest.fail "expected active generation")
  | Error e -> Alcotest.fail ("expected Ok: " ^ e)

let test_start_generation_already_active () =
  let session = Ribosome.Session.create ~id:"s1" ~mode:Ribosome.Mode.ui in
  let session =
    match Ribosome.Session.start_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail ("first start: " ^ e)
  in
  match Ribosome.Session.start_generation session ~gen_id:"g2" with
  | Ok _ -> Alcotest.fail "expected error for second generation"
  | Error _ -> Alcotest.(check bool) "rejected second gen" true true

let test_start_generation_preserves_tree () =
  let session = Ribosome.Session.create ~id:"s1" ~mode:Ribosome.Mode.ui in
  let json =
    "{\"kind\":\"text\",\"id\":\"t\",\"text_type\":\"Paragraph\",\"value\":\"hi\"}"
  in
  let session =
    match Ribosome.Session.start_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  let session, _ =
    match feed_delta_seq session "g1" 0 json with
    | Ok r -> r
    | Error e -> Alcotest.fail e
  in
  let tree = session.tree in
  let session =
    match Ribosome.Session.complete_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  let session =
    match Ribosome.Session.start_generation session ~gen_id:"g2" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  Alcotest.(check bool)
    "tree preserved across generation" true (session.tree = tree)

(* --- feed delta --- *)

let test_feed_delta_updates_tree () =
  let session = Ribosome.Session.create ~id:"s1" ~mode:Ribosome.Mode.ui in
  let session =
    match Ribosome.Session.start_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  let json =
    "{\"kind\":\"text\",\"id\":\"t\",\"text_type\":\"Paragraph\",\"value\":\"hi\"}"
  in
  let session, update =
    match feed_delta_seq session "g1" 0 json with
    | Ok r -> r
    | Error e -> Alcotest.fail e
  in
  (match update with
  | Ribosome.Incremental.Updated tree ->
      Alcotest.(check bool) "tree updated" true (tree = text "t" "hi")
  | _ -> Alcotest.fail "expected Updated");
  Alcotest.(check int) "revision incremented" 1 session.revision

let test_feed_delta_no_generation () =
  let session = Ribosome.Session.create ~id:"s1" ~mode:Ribosome.Mode.ui in
  match feed_delta_seq session "g1" 0 "x" with
  | Ok _ -> Alcotest.fail "expected error"
  | Error _ -> Alcotest.(check bool) "rejected no generation" true true

let test_feed_delta_wrong_generation () =
  let session = Ribosome.Session.create ~id:"s1" ~mode:Ribosome.Mode.ui in
  let session =
    match Ribosome.Session.start_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  match feed_delta_seq session "g2" 0 "x" with
  | Ok _ -> Alcotest.fail "expected error"
  | Error _ -> Alcotest.(check bool) "rejected wrong generation" true true

let test_feed_delta_out_of_order () =
  let session = Ribosome.Session.create ~id:"s1" ~mode:Ribosome.Mode.ui in
  let session =
    match Ribosome.Session.start_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  let json1 =
    "{\"kind\":\"text\",\"id\":\"t\",\"text_type\":\"Paragraph\",\"value\":\"a\"}"
  in
  let session, _ =
    match feed_delta_seq session "g1" 0 json1 with
    | Ok r -> r
    | Error e -> Alcotest.fail e
  in
  match feed_delta_seq session "g1" 2 "x" with
  | Ok _ -> Alcotest.fail "expected error"
  | Error _ -> Alcotest.(check bool) "rejected out of order" true true

let test_feed_delta_duplicate_seq () =
  let session = Ribosome.Session.create ~id:"s1" ~mode:Ribosome.Mode.ui in
  let session =
    match Ribosome.Session.start_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  let json =
    "{\"kind\":\"text\",\"id\":\"t\",\"text_type\":\"Paragraph\",\"value\":\"hi\"}"
  in
  let session, _ =
    match feed_delta_seq session "g1" 0 json with
    | Ok r -> r
    | Error e -> Alcotest.fail e
  in
  match feed_delta_seq session "g1" 0 json with
  | Ok _ -> Alcotest.fail "expected error"
  | Error _ -> Alcotest.(check bool) "rejected duplicate seq" true true

(* --- complete / fail / cancel --- *)

let test_complete_generation () =
  let session = Ribosome.Session.create ~id:"s1" ~mode:Ribosome.Mode.ui in
  let session =
    match Ribosome.Session.start_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  let session =
    match Ribosome.Session.complete_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  Alcotest.(check (option pass)) "generation cleared" None session.generation

let test_fail_generation () =
  let session = Ribosome.Session.create ~id:"s1" ~mode:Ribosome.Mode.ui in
  let session =
    match Ribosome.Session.start_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  let session =
    match Ribosome.Session.fail_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  Alcotest.(check (option pass)) "generation cleared" None session.generation

let test_cancel_generation () =
  let session = Ribosome.Session.create ~id:"s1" ~mode:Ribosome.Mode.ui in
  let session =
    match Ribosome.Session.start_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  let session =
    match Ribosome.Session.cancel_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  Alcotest.(check (option pass)) "generation cleared" None session.generation

let test_complete_wrong_generation () =
  let session = Ribosome.Session.create ~id:"s1" ~mode:Ribosome.Mode.ui in
  let session =
    match Ribosome.Session.start_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  match Ribosome.Session.complete_generation session ~gen_id:"g2" with
  | Ok _ -> Alcotest.fail "expected error"
  | Error _ -> Alcotest.(check bool) "rejected wrong gen" true true

(* --- multiple deltas in sequence --- *)

let test_multiple_deltas_sequence () =
  let session = Ribosome.Session.create ~id:"s1" ~mode:Ribosome.Mode.ui in
  let session =
    match Ribosome.Session.start_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  (* Stream a single JSON template across two deltas.
     The first chunk is closable by Telomere (string "hel" + close braces),
     producing an intermediate Updated. The second chunk replaces it. *)
  let delta1 =
    "{\"kind\":\"text\",\"id\":\"t\",\"text_type\":\"Paragraph\",\"value\":\"hel"
  in
  let delta2 = "lo\"}" in
  let session, update1 =
    match feed_delta_seq session "g1" 0 delta1 with
    | Ok r -> r
    | Error e -> Alcotest.fail e
  in
  (match update1 with
  | Ribosome.Incremental.Updated tree ->
      Alcotest.(check bool)
        "first chunk commits intermediate" true
        (tree = text "t" "hel")
  | _ -> Alcotest.fail "expected Updated after first chunk");
  Alcotest.(check int) "revision 1 after first" 1 session.revision;
  let session, update2 =
    match feed_delta_seq session "g1" 1 delta2 with
    | Ok r -> r
    | Error e -> Alcotest.fail e
  in
  (match update2 with
  | Ribosome.Incremental.Updated tree ->
      Alcotest.(check bool)
        "completed after second chunk" true
        (tree = text "t" "hello")
  | _ -> Alcotest.fail "expected Updated after completion");
  Alcotest.(check int) "revision 2" 2 session.revision

let () =
  Alcotest.run "ribosome-session"
    [
      ( "lifecycle",
        [
          Alcotest.test_case "create" `Quick test_create;
          Alcotest.test_case "start generation" `Quick test_start_generation;
          Alcotest.test_case "start when already active" `Quick
            test_start_generation_already_active;
          Alcotest.test_case "start preserves tree" `Quick
            test_start_generation_preserves_tree;
          Alcotest.test_case "feed delta updates" `Quick
            test_feed_delta_updates_tree;
          Alcotest.test_case "feed no generation" `Quick
            test_feed_delta_no_generation;
          Alcotest.test_case "feed wrong generation" `Quick
            test_feed_delta_wrong_generation;
          Alcotest.test_case "feed out of order" `Quick
            test_feed_delta_out_of_order;
          Alcotest.test_case "feed duplicate seq" `Quick
            test_feed_delta_duplicate_seq;
          Alcotest.test_case "complete generation" `Quick
            test_complete_generation;
          Alcotest.test_case "fail generation" `Quick test_fail_generation;
          Alcotest.test_case "cancel generation" `Quick test_cancel_generation;
          Alcotest.test_case "complete wrong generation" `Quick
            test_complete_wrong_generation;
          Alcotest.test_case "multiple deltas sequence" `Quick
            test_multiple_deltas_sequence;
        ] );
    ]
