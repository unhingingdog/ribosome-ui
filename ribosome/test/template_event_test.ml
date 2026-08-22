open Ribosome.Template

let text id value = Text Text.{ id; text_type = Paragraph; value }

let input_field id value =
  Submittable.FieldInput Input.{ id; value = Some value }

let select_field id label options selected =
  Submittable.FieldSelect
    Select.{ id; label; options; selected = Some selected }

let submit_event target_id = Ribosome.Event.Submit { target_id }
let click_event target_id = Ribosome.Event.Click { target_id }
let change_event target_id value = Ribosome.Event.Change { target_id; value }

let form_tree () =
  Submittable
    Submittable.
      {
        id = "form";
        value =
          [
            input_field "name" (String "Alice");
            select_field "color" "Color"
              [
                { value = "r"; label = "Red" }; { value = "g"; label = "Green" };
              ]
              "r";
          ];
        button =
          Some
            Button.
              { id = "go"; label = "Go"; action = Submit; disabled = false };
      }

let check_ok name tree event expected_tree =
  match Ribosome.Event.apply tree event with
  | Ok (actual_tree, _) ->
      Alcotest.(check bool) name true (actual_tree = expected_tree)
  | Error e -> Alcotest.fail (name ^ ": expected Ok but got Error: " ^ e)

let check_error name tree event =
  match Ribosome.Event.apply tree event with
  | Ok _ -> Alcotest.fail (name ^ ": expected Error")
  | Error _ -> Alcotest.(check bool) (name ^ ": is error") true true

(* --- change input --- *)

let test_change_input () =
  let tree = form_tree () in
  let event = change_event "name" (String "Bob") in
  let expected =
    Submittable
      Submittable.
        {
          id = "form";
          value =
            [
              input_field "name" (String "Bob");
              select_field "color" "Color"
                [
                  { value = "r"; label = "Red" };
                  { value = "g"; label = "Green" };
                ]
                "r";
            ];
          button =
            Some
              Button.
                { id = "go"; label = "Go"; action = Submit; disabled = false };
        }
  in
  check_ok "change input" tree event expected

(* --- change select --- *)

let test_change_select () =
  let tree = form_tree () in
  let event = change_event "color" (String "g") in
  let expected =
    Submittable
      Submittable.
        {
          id = "form";
          value =
            [
              input_field "name" (String "Alice");
              select_field "color" "Color"
                [
                  { value = "r"; label = "Red" };
                  { value = "g"; label = "Green" };
                ]
                "g";
            ];
          button =
            Some
              Button.
                { id = "go"; label = "Go"; action = Submit; disabled = false };
        }
  in
  check_ok "change select" tree event expected

(* --- submit --- *)

let test_submit () =
  let tree = form_tree () in
  let event = submit_event "form" in
  check_ok "submit" tree event tree

(* --- click button --- *)

let test_click_button () =
  let tree = form_tree () in
  let event = click_event "go" in
  check_ok "click button" tree event tree

(* --- unknown target --- *)

let test_change_unknown () =
  let tree = form_tree () in
  let event = change_event "missing" (String "x") in
  check_error "change unknown" tree event

let test_submit_unknown () =
  let tree = form_tree () in
  let event = submit_event "missing" in
  check_error "submit unknown" tree event

let test_click_unknown () =
  let tree = form_tree () in
  let event = click_event "missing" in
  check_error "click unknown" tree event

(* --- wrong target type --- *)

let test_change_on_text () =
  let tree = text "t" "hello" in
  let event = change_event "t" (String "x") in
  check_error "change on text" tree event

let test_click_on_text () =
  let tree = text "t" "hello" in
  let event = click_event "t" in
  check_error "click on text" tree event

let test_submit_on_text () =
  let tree = text "t" "hello" in
  let event = submit_event "t" in
  check_error "submit on text" tree event

(* --- invalid value for select --- *)

let test_change_select_with_int () =
  let tree = form_tree () in
  let event = change_event "color" (Int 42) in
  check_error "change select with int" tree event

(* --- preserve unrelated nodes --- *)

let test_change_preserves_siblings () =
  let tree =
    Container
      Container.
        {
          id = "root";
          direction = Vertical;
          children = [ text "a" "keep"; form_tree (); text "b" "also keep" ];
        }
  in
  let event = change_event "name" (String "Charlie") in
  match Ribosome.Event.apply tree event with
  | Ok (Container c, _) -> (
      match c.children with
      | [ Text a; _; Text b ] ->
          Alcotest.(check string) "sibling a preserved" "keep" a.value;
          Alcotest.(check string) "sibling b preserved" "also keep" b.value
      | _ -> Alcotest.fail "unexpected children")
  | _ -> Alcotest.fail "expected container"

(* --- deeply nested change --- *)

let test_change_deeply_nested () =
  let tree =
    Container
      Container.
        {
          id = "root";
          direction = Vertical;
          children =
            [
              Container
                Container.
                  {
                    id = "mid";
                    direction = Vertical;
                    children = [ form_tree () ];
                  };
            ];
        }
  in
  let event = change_event "name" (String "Deep") in
  match Ribosome.Event.apply tree event with
  | Ok (Container root, _) -> (
      match root.children with
      | [ Container mid ] -> (
          match mid.children with
          | [ Submittable s ] -> (
              match s.value with
              | [ Submittable.FieldInput input; Submittable.FieldSelect _ ] ->
                  Alcotest.(check string)
                    "deeply nested input updated" "Deep"
                    (match input.value with
                    | Some (String v) -> v
                    | _ -> "FAIL")
              | _ -> Alcotest.fail "unexpected fields")
          | _ -> Alcotest.fail "unexpected mid children")
      | _ -> Alcotest.fail "unexpected root children")
  | _ -> Alcotest.fail "expected ok"

let () =
  Alcotest.run "ribosome-event"
    [
      ( "apply",
        [
          Alcotest.test_case "change input" `Quick test_change_input;
          Alcotest.test_case "change select" `Quick test_change_select;
          Alcotest.test_case "submit" `Quick test_submit;
          Alcotest.test_case "click button" `Quick test_click_button;
          Alcotest.test_case "change unknown" `Quick test_change_unknown;
          Alcotest.test_case "submit unknown" `Quick test_submit_unknown;
          Alcotest.test_case "click unknown" `Quick test_click_unknown;
          Alcotest.test_case "change on text" `Quick test_change_on_text;
          Alcotest.test_case "click on text" `Quick test_click_on_text;
          Alcotest.test_case "submit on text" `Quick test_submit_on_text;
          Alcotest.test_case "change select with int" `Quick
            test_change_select_with_int;
          Alcotest.test_case "preserve siblings" `Quick
            test_change_preserves_siblings;
          Alcotest.test_case "change deeply nested" `Quick
            test_change_deeply_nested;
        ] );
    ]
