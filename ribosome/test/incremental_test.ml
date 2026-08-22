open Ribosome.Template

let text id value = Text Text.{ id; text_type = Paragraph; value }

let _container id children =
  Container Container.{ id; direction = Vertical; children }

let feed_chars state s =
  let chars =
    String.to_seq s |> Stdlib.List.of_seq |> Stdlib.List.map (String.make 1)
  in
  Stdlib.List.fold_left
    (fun (state, updates) chunk ->
      let new_state, update = Ribosome.Incremental.feed state chunk in
      (new_state, updates @ [ update ]))
    (state, []) chars

let all_updates updates =
  Stdlib.List.filter_map
    (function Ribosome.Incremental.Updated tree -> Some tree | _ -> None)
    updates

let last_updated updates =
  match Stdlib.List.rev updates with
  | [] -> None
  | updates ->
      Stdlib.List.find_opt
        (function Ribosome.Incremental.Updated _ -> true | _ -> false)
        updates

(* --- text template streamed one char at a time --- *)

let test_text_one_char_at_a_time () =
  let state = Ribosome.Incremental.create () in
  let json =
    "{\"kind\":\"text\",\"id\":\"t\",\"text_type\":\"Paragraph\",\"value\":\"hi\"}"
  in
  let _, updates = feed_chars state json in
  let trees = all_updates updates in
  Alcotest.(check bool)
    "multiple progressive commits" true
    (Stdlib.List.length trees > 1);
  match last_updated updates with
  | Some (Updated tree) ->
      Alcotest.(check bool) "final tree is text" true (tree = text "t" "hi")
  | _ -> Alcotest.fail "expected final Updated"

(* --- incomplete string produces progressive commits --- *)

let test_incomplete_string_progressive () =
  let state = Ribosome.Incremental.create () in
  let json =
    "{\"kind\":\"text\",\"id\":\"t\",\"text_type\":\"Paragraph\",\"value\":\"incomplete"
  in
  let new_state, updates = feed_chars state json in
  let trees = all_updates updates in
  let values =
    Stdlib.List.filter_map (function Text t -> Some t.value | _ -> None) trees
  in
  (* Values should grow progressively longer as chars stream in *)
  Alcotest.(check int) "values length" 11 (Stdlib.List.length values);
  Alcotest.(check string)
    "last value" "incomplete"
    (Stdlib.List.hd (Stdlib.List.rev values));
  (* The progressive commits already produced the final tree with
     value="incomplete". Feeding the closing quote should not produce a new
     Updated because it matches the already-committed tree. *)
  let state_after_quote, update1 = Ribosome.Incremental.feed new_state "\"" in
  (match update1 with
  | Pending -> ()
  | Updated tree ->
      Alcotest.(check bool)
        "completed tree after quote" true
        (tree = text "t" "incomplete")
  | _ -> Alcotest.fail "expected Pending or Updated after closing quote");
  (* Extra closing brace should not produce a new Updated *)
  let _, update2 = Ribosome.Incremental.feed state_after_quote "}" in
  match update2 with
  | Updated _ -> Alcotest.fail "expected no Updated for extra brace"
  | _ -> ()

(* --- partial nested children never delete committed siblings --- *)

let test_partial_nested_preserves_siblings () =
  let state = Ribosome.Incremental.create () in
  (* First complete a container with two children *)
  let json1 =
    "{\"kind\":\"container\",\"id\":\"root\",\"direction\":\"Vertical\",\"children\":["
    ^ "{\"kind\":\"text\",\"id\":\"a\",\"text_type\":\"Paragraph\",\"value\":\"first\"}"
    ^ ","
    ^ "{\"kind\":\"text\",\"id\":\"b\",\"text_type\":\"Paragraph\",\"value\":\"second\"}"
    ^ "]}"
  in
  let state, updates1 = feed_chars state json1 in
  let trees1 = all_updates updates1 in
  (* Should have at least one commit with both children *)
  let has_both =
    Stdlib.List.exists
      (function
        | Container c ->
            Stdlib.List.exists
              (fun child -> Ribosome.Template.id child = "b")
              c.children
        | _ -> false)
      trees1
  in
  Alcotest.(check bool) "initial commit has both children" true has_both;
  (* Now stream a replacement for child a, but leave it incomplete *)
  let json2 =
    "{\"kind\":\"container\",\"id\":\"root\",\"direction\":\"Vertical\",\"children\":["
    ^ "{\"kind\":\"text\",\"id\":\"a\",\"text_type\":\"Paragraph\",\"value\":\"updated"
  in
  let state, updates2 = feed_chars state json2 in
  (* Even with partial child, all commits should still have sibling b *)
  let trees2 = all_updates updates2 in
  let all_have_b =
    Stdlib.List.for_all
      (function
        | Container c ->
            Stdlib.List.exists
              (fun child -> Ribosome.Template.id child = "b")
              c.children
        | _ -> false)
      trees2
  in
  Alcotest.(check bool) "partial never deletes sibling b" true all_have_b;
  (* Complete the replacement *)
  let _state, _ = feed_chars state "\"}" in
  (* Close the container too *)
  let state = Ribosome.Incremental.create () in
  let json3 =
    "{\"kind\":\"container\",\"id\":\"root\",\"direction\":\"Vertical\",\"children\":["
    ^ "{\"kind\":\"text\",\"id\":\"a\",\"text_type\":\"Paragraph\",\"value\":\"updated\"}"
    ^ ","
    ^ "{\"kind\":\"text\",\"id\":\"b\",\"text_type\":\"Paragraph\",\"value\":\"second\"}"
    ^ "]}"
  in
  let _, updates3 = feed_chars state json3 in
  match last_updated updates3 with
  | Some (Updated (Container c)) -> (
      match c.children with
      | [ Text a; Text b ] ->
          Alcotest.(check string) "child a updated" "updated" a.value;
          Alcotest.(check string) "child b preserved" "second" b.value
      | _ -> Alcotest.fail "unexpected children")
  | _ -> Alcotest.fail "expected container"

(* --- unknown patch ID is rejected --- *)

let test_unknown_patch_rejected () =
  let state = Ribosome.Incremental.create () in
  let json1 =
    "{\"kind\":\"text\",\"id\":\"root\",\"text_type\":\"Paragraph\",\"value\":\"x\"}"
  in
  let state, updates1 = feed_chars state json1 in
  let trees1 = all_updates updates1 in
  Alcotest.(check bool)
    "first feed commits" true
    (Stdlib.List.length trees1 >= 1);
  (* Now send a different ID — reconciler should reject *)
  let json2 =
    "{\"kind\":\"text\",\"id\":\"other\",\"text_type\":\"Paragraph\",\"value\":\"y\"}"
  in
  let _state2, updates2 = feed_chars state json2 in
  let has_rejected =
    Stdlib.List.exists
      (function Ribosome.Incremental.Rejected _ -> true | _ -> false)
      updates2
  in
  Alcotest.(check bool) "has rejection" true has_rejected;
  (* Ensure the last event is Rejected, not Updated *)
  (match Stdlib.List.rev updates2 with
  | Rejected _ :: _ -> ()
  | _ -> Alcotest.fail "expected final event to be Rejected");
  (* Ensure the final event of the second feed was Rejected *)
  match Stdlib.List.rev updates2 with
  | Rejected _ :: _ -> ()
  | _ -> Alcotest.fail "expected final event of second feed to be Rejected"

(* --- corruption stops all future commits --- *)

let test_corruption_stops_commits () =
  let state = Ribosome.Incremental.create () in
  let state, _ =
    feed_chars state
      "{\"kind\":\"text\",\"id\":\"t\",\"text_type\":\"Paragraph\",\"value\":\"ok\"}"
  in
  (* Send corrupted JSON: extra closing brace at wrong nesting *)
  let state2, update = Ribosome.Incremental.feed state "}" in
  (match update with
  | Corrupted -> ()
  | _ -> Alcotest.fail "expected Corrupted");
  (* Subsequent valid JSON should not commit *)
  let _, update2 = Ribosome.Incremental.feed state2 "{\"a\":1}" in
  match update2 with
  | Corrupted -> ()
  | _ -> Alcotest.fail "expected Corrupted to persist"

(* --- suppress equal updates --- *)

let test_suppress_equal_updates () =
  let state = Ribosome.Incremental.create () in
  let json =
    "{\"kind\":\"text\",\"id\":\"t\",\"text_type\":\"Paragraph\",\"value\":\"same\"}"
  in
  let state, updates1 = feed_chars state json in
  let trees1 = all_updates updates1 in
  Alcotest.(check bool)
    "first feed commits" true
    (Stdlib.List.length trees1 >= 1);
  (* Feed the exact same JSON again *)
  let _, updates2 = feed_chars state json in
  let trees2 = all_updates updates2 in
  Alcotest.(check int) "duplicate suppressed" 0 (Stdlib.List.length trees2)

let () =
  Alcotest.run "ribosome-incremental"
    [
      ( "feed",
        [
          Alcotest.test_case "text one char at a time" `Quick
            test_text_one_char_at_a_time;
          Alcotest.test_case "incomplete string progressive" `Quick
            test_incomplete_string_progressive;
          Alcotest.test_case "partial nested preserves siblings" `Quick
            test_partial_nested_preserves_siblings;
          Alcotest.test_case "unknown patch rejected" `Quick
            test_unknown_patch_rejected;
          Alcotest.test_case "corruption stops commits" `Quick
            test_corruption_stops_commits;
          Alcotest.test_case "suppress equal updates" `Quick
            test_suppress_equal_updates;
        ] );
    ]
