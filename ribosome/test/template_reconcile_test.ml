open Ribosome.Template

let text id value = Text Text.{ id; text_type = Paragraph; value }

let container id children =
  Container Container.{ id; direction = Vertical; children }

let list_ id children = List List.{ id; ordered = None; children }

let check_ok name tree expected =
  match tree with
  | Ok actual -> Alcotest.(check bool) name true (actual = expected)
  | Error e -> Alcotest.fail (name ^ ": expected Ok but got Error: " ^ e)

let check_error name tree =
  match tree with
  | Ok _ -> Alcotest.fail (name ^ ": expected Error")
  | Error _ -> Alcotest.(check bool) (name ^ ": is error") true true

(* --- root replacement --- *)

let test_replace_root () =
  let original = text "root" "old" in
  let replacement = text "root" "new" in
  check_ok "root replaced"
    (Ribosome.Reconcile.patch ~target_id:"root" ~replacement original)
    replacement

(* --- child replacement --- *)

let test_replace_child () =
  let original = container "root" [ text "a" "old"; text "b" "keep" ] in
  let replacement = text "a" "new" in
  let expected = container "root" [ text "a" "new"; text "b" "keep" ] in
  check_ok "child replaced"
    (Ribosome.Reconcile.patch ~target_id:"a" ~replacement original)
    expected

(* --- deeply nested replacement --- *)

let test_replace_deeply_nested () =
  let original =
    container "root"
      [ container "mid" [ text "leaf" "old" ]; text "sibling" "keep" ]
  in
  let replacement = text "leaf" "new" in
  let expected =
    container "root"
      [ container "mid" [ text "leaf" "new" ]; text "sibling" "keep" ]
  in
  check_ok "deeply nested replaced"
    (Ribosome.Reconcile.patch ~target_id:"leaf" ~replacement original)
    expected

(* --- list replacement --- *)

let test_replace_list_child () =
  let original =
    container "root" [ list_ "items" [ text "i1" "old"; text "i2" "keep" ] ]
  in
  let replacement = text "i1" "new" in
  let expected =
    container "root" [ list_ "items" [ text "i1" "new"; text "i2" "keep" ] ]
  in
  check_ok "list child replaced"
    (Ribosome.Reconcile.patch ~target_id:"i1" ~replacement original)
    expected

(* --- missing target --- *)

let test_missing_target () =
  let original = container "root" [ text "a" "x" ] in
  let replacement = text "z" "y" in
  check_error "missing target"
    (Ribosome.Reconcile.patch ~target_id:"z" ~replacement original)

(* --- submittable fields are not patch anchors --- *)

let test_submittable_field_not_anchor () =
  let original =
    Submittable
      Submittable.
        {
          id = "form";
          value = [ FieldInput Input.{ id = "name"; value = None } ];
          button = None;
        }
  in
  let replacement = text "name" "injected" in
  check_error "submittable field not patchable"
    (Ribosome.Reconcile.patch ~target_id:"name" ~replacement original)

(* --- preserve unaffected siblings and order --- *)

let test_preserve_siblings_and_order () =
  let original =
    container "root" [ text "a" "1"; text "b" "2"; text "c" "3"; text "d" "4" ]
  in
  let replacement = text "c" "three" in
  let expected =
    container "root"
      [ text "a" "1"; text "b" "2"; text "c" "three"; text "d" "4" ]
  in
  check_ok "siblings preserved"
    (Ribosome.Reconcile.patch ~target_id:"c" ~replacement original)
    expected

(* --- replace container with leaf --- *)

let test_replace_container_with_leaf () =
  let original = container "root" [ text "a" "x" ] in
  let replacement = text "root" "replaced" in
  check_ok "container replaced by leaf"
    (Ribosome.Reconcile.patch ~target_id:"root" ~replacement original)
    replacement

(* --- replace leaf with container --- *)

let test_replace_leaf_with_container () =
  let original = container "root" [ text "a" "x" ] in
  let replacement = container "a" [ text "b" "y" ] in
  let expected = container "root" [ container "a" [ text "b" "y" ] ] in
  check_ok "leaf replaced by container"
    (Ribosome.Reconcile.patch ~target_id:"a" ~replacement original)
    expected

let () =
  Alcotest.run "ribosome-reconcile"
    [
      ( "patch",
        [
          Alcotest.test_case "replace root" `Quick test_replace_root;
          Alcotest.test_case "replace child" `Quick test_replace_child;
          Alcotest.test_case "replace deeply nested" `Quick
            test_replace_deeply_nested;
          Alcotest.test_case "replace list child" `Quick test_replace_list_child;
          Alcotest.test_case "missing target" `Quick test_missing_target;
          Alcotest.test_case "submittable field not anchor" `Quick
            test_submittable_field_not_anchor;
          Alcotest.test_case "preserve siblings" `Quick
            test_preserve_siblings_and_order;
          Alcotest.test_case "replace container with leaf" `Quick
            test_replace_container_with_leaf;
          Alcotest.test_case "replace leaf with container" `Quick
            test_replace_leaf_with_container;
        ] );
    ]
