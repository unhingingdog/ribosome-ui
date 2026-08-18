open Ribosome_core
open Ribosome_incremental

let assert_equal label expected actual =
  if expected <> actual then failwith label

let text content =
  Types.Text {
    Templates.Text.kind = "text";
    id = "title";
    text_type = Templates.Text.Paragraph;
    content;
  }

let test_preserves_tree_for_incomplete_json () =
  let state = Incremental.create (Some (text "Before")) in
  let update, next = Incremental.feed state "{\"kind\":\"text\"" in
  assert_equal "incomplete template does not update" true
    (match update with Incremental.Rejected _ -> true | _ -> false);
  assert_equal "incomplete json preserves committed tree" state.committed next.committed

let test_updates_from_a_complete_candidate () =
  let state = Incremental.create (Some (text "Before")) in
  let update, next = Incremental.feed state
    "{\"kind\":\"text\",\"id\":\"title\",\"text_type\":\"Paragraph\",\"value\":\"After\"}" in
  assert_equal "complete candidate reconciles" (Incremental.Updated (text "After")) update;
  assert_equal "reconciled tree is committed" (Some (text "After")) next.committed

let test_preserves_tree_for_rejected_candidate () =
  let state = Incremental.create (Some (text "Before")) in
  let update, next = Incremental.feed state "{\"kind\":\"unknown\"}" in
  assert_equal "unknown template is rejected" (Incremental.Rejected "unknown template kind") update;
  assert_equal "rejected candidate preserves committed tree" state.committed next.committed

let () =
  test_preserves_tree_for_incomplete_json ();
  test_updates_from_a_complete_candidate ();
  test_preserves_tree_for_rejected_candidate ()
