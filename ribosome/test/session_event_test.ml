open Ribosome.Template

let _text id value = Text Text.{ id; text_type = Paragraph; value }
let submit_event target_id = Ribosome.Event.Submit { target_id }
let click_event target_id = Ribosome.Event.Click { target_id }
let change_event target_id value = Ribosome.Event.Change { target_id; value }

let session_with_tree tree =
  let session = Ribosome.Session.create ~id:"s1" ~mode:Ribosome.Mode.ui in
  let session =
    match Ribosome.Session.start_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  let json = Ribosome.Template.encode_string tree in
  let session, _ =
    match
      Ribosome.Session.feed_delta session ~gen_id:"g1" ~seq:0 ~delta:json
    with
    | Ok r -> r
    | Error e -> Alcotest.fail e
  in
  let session =
    match Ribosome.Session.complete_generation session ~gen_id:"g1" with
    | Ok s -> s
    | Error e -> Alcotest.fail e
  in
  session

(* --- apply change event locally --- *)

let test_apply_change () =
  let tree =
    Submittable
      Submittable.
        {
          id = "form";
          value =
            [ FieldInput Input.{ id = "name"; value = Some (String "Alice") } ];
          button = None;
        }
  in
  let session = session_with_tree tree in
  let event = change_event "name" (String "Bob") in
  match
    Ribosome.Session.apply_event session ~event_id:"e1" ~base_revision:1 event
  with
  | Ok (Updated s) -> (
      Alcotest.(check int) "revision incremented" 2 s.revision;
      match s.tree with
      | Some (Submittable sub) -> (
          match sub.value with
          | [ FieldInput input ] -> (
              match input.value with
              | Some (String "Bob") -> ()
              | _ -> Alcotest.fail "value not updated")
          | _ -> Alcotest.fail "unexpected fields")
      | _ -> Alcotest.fail "expected submittable")
  | Ok (UserTurn _) -> Alcotest.fail "expected Updated for change"
  | Error e -> Alcotest.fail e

(* --- apply click event produces user turn --- *)

let test_apply_click () =
  let tree =
    Submittable
      Submittable.
        {
          id = "form";
          value = [];
          button =
            Some
              Button.
                { id = "go"; label = "Go"; action = Submit; disabled = false };
        }
  in
  let session = session_with_tree tree in
  let event = click_event "go" in
  match
    Ribosome.Session.apply_event session ~event_id:"e1" ~base_revision:1 event
  with
  | Ok (UserTurn (s, returned_tree, returned_event)) ->
      Alcotest.(check int) "revision incremented" 2 s.revision;
      Alcotest.(check bool) "tree returned" true (returned_tree = tree);
      Alcotest.(check bool) "event returned" true (returned_event = event)
  | Ok (Updated _) -> Alcotest.fail "expected UserTurn for click"
  | Error e -> Alcotest.fail e

(* --- apply submit event produces user turn --- *)

let test_apply_submit () =
  let tree =
    Submittable Submittable.{ id = "form"; value = []; button = None }
  in
  let session = session_with_tree tree in
  let event = submit_event "form" in
  match
    Ribosome.Session.apply_event session ~event_id:"e1" ~base_revision:1 event
  with
  | Ok (UserTurn (s, returned_tree, returned_event)) ->
      Alcotest.(check int) "revision incremented" 2 s.revision;
      Alcotest.(check bool) "tree returned" true (returned_tree = tree);
      Alcotest.(check bool) "event returned" true (returned_event = event)
  | Ok (Updated _) -> Alcotest.fail "expected UserTurn for submit"
  | Error e -> Alcotest.fail e

(* --- stale revision rejected --- *)

let test_stale_revision () =
  let tree =
    Submittable
      Submittable.
        {
          id = "form";
          value = [];
          button =
            Some
              Button.
                { id = "go"; label = "Go"; action = Submit; disabled = false };
        }
  in
  let session = session_with_tree tree in
  let event = click_event "go" in
  match
    Ribosome.Session.apply_event session ~event_id:"e1" ~base_revision:0 event
  with
  | Ok _ -> Alcotest.fail "expected error for stale revision"
  | Error _ -> Alcotest.(check bool) "stale rejected" true true

(* --- duplicate event id rejected --- *)

let test_duplicate_event_id () =
  let tree =
    Submittable
      Submittable.
        {
          id = "form";
          value = [];
          button =
            Some
              Button.
                { id = "go"; label = "Go"; action = Submit; disabled = false };
        }
  in
  let session = session_with_tree tree in
  let event = click_event "go" in
  let session =
    match
      Ribosome.Session.apply_event session ~event_id:"e1" ~base_revision:1 event
    with
    | Ok (UserTurn (s, _, _)) -> s
    | Ok (Updated s) -> s
    | Error e -> Alcotest.fail e
  in
  match
    Ribosome.Session.apply_event session ~event_id:"e1" ~base_revision:2 event
  with
  | Ok _ -> Alcotest.fail "expected error for duplicate event id"
  | Error _ -> Alcotest.(check bool) "duplicate rejected" true true

(* --- no tree rejects event --- *)

let test_no_tree () =
  let session = Ribosome.Session.create ~id:"s1" ~mode:Ribosome.Mode.ui in
  let event = click_event "t" in
  match
    Ribosome.Session.apply_event session ~event_id:"e1" ~base_revision:0 event
  with
  | Ok _ -> Alcotest.fail "expected error for no tree"
  | Error _ -> Alcotest.(check bool) "no tree rejected" true true

(* --- event window is bounded --- *)

let test_event_window_bounded () =
  let tree =
    Submittable
      Submittable.
        {
          id = "form";
          value =
            [ FieldInput Input.{ id = "name"; value = Some (String "x") } ];
          button = None;
        }
  in
  let session = session_with_tree tree in
  let session =
    Stdlib.List.fold_left
      (fun session i ->
        let event = change_event "name" (String (string_of_int i)) in
        match
          Ribosome.Session.apply_event session
            ~event_id:("e" ^ string_of_int i)
            ~base_revision:session.revision event
        with
        | Ok (Updated s) -> s
        | Ok (UserTurn (s, _, _)) -> s
        | Error e -> Alcotest.fail e)
      session
      (Stdlib.List.init 105 (fun i -> i))
  in
  Alcotest.(check int)
    "recent_event_ids bounded" 100
    (Stdlib.List.length session.recent_event_ids);
  Alcotest.(check bool)
    "oldest dropped" false
    (Stdlib.List.mem "e0" session.recent_event_ids);
  Alcotest.(check bool)
    "newest kept" true
    (Stdlib.List.mem "e104" session.recent_event_ids)

let () =
  Alcotest.run "ribosome-session-events"
    [
      ( "events",
        [
          Alcotest.test_case "apply change" `Quick test_apply_change;
          Alcotest.test_case "apply click" `Quick test_apply_click;
          Alcotest.test_case "apply submit" `Quick test_apply_submit;
          Alcotest.test_case "stale revision" `Quick test_stale_revision;
          Alcotest.test_case "duplicate event id" `Quick test_duplicate_event_id;
          Alcotest.test_case "no tree" `Quick test_no_tree;
          Alcotest.test_case "event window bounded" `Quick
            test_event_window_bounded;
        ] );
    ]
