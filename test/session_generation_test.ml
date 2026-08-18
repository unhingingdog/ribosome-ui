open Ribosome_session

let assert_equal label expected actual =
  if expected <> actual then failwith label

let ready_session () =
  match Session.attach_thread (Session.create ~initial_prompt:"Initial request" "session-1") Codex_client.Thread.{ id = "thread-1" } with
  | Ok session -> session
  | Error _ -> failwith "expected thread attachment"

let turn = Codex_client.Turn.{ id = "turn-1" }

let test_starts_one_generation () =
  let session = ready_session () in
  let active = match Session.start_generation session turn with
    | Ok session -> session
    | Error _ -> failwith "expected active generation"
  in
  assert_equal "an active session records its Codex turn"
    (Some Session.{ turn; cancellation_requested = false }) active.generation;
  assert_equal "only one turn can run in a session"
    (Error Session.Generation_already_active) (Session.start_generation active turn)

let test_completes_matching_turn () =
  let session = ready_session () in
  let active = match Session.start_generation session turn with
    | Ok session -> session
    | Error _ -> failwith "expected active generation"
  in
  match Session.complete_generation active "turn-1" with
  | Ok session -> assert_equal "completion clears active generation" None session.generation
  | Error _ -> failwith "expected completion"

let test_marks_cancellation_before_interrupt () =
  let session = ready_session () in
  let active = match Session.start_generation session turn with
    | Ok session -> session
    | Error _ -> failwith "expected active generation"
  in
  match Session.request_cancellation active with
  | Ok (session, interrupted_turn) ->
    assert_equal "cancellation keeps the target turn" turn interrupted_turn;
    assert_equal "cancellation blocks duplicate interrupt commands"
      (Some Session.{ turn; cancellation_requested = true }) session.generation
  | Error _ -> failwith "expected cancellation"

let test_rejects_wrong_completion () =
  let session = ready_session () in
  let active = match Session.start_generation session turn with
    | Ok session -> session
    | Error _ -> failwith "expected active generation"
  in
  assert_equal "another turn cannot complete this session"
    (Error Session.Wrong_turn) (Session.complete_generation active "turn-2")

let test_failure_clears_matching_turn () =
  let session = ready_session () in
  let active = match Session.start_generation session turn with
    | Ok session -> session
    | Error _ -> failwith "expected active generation"
  in
  match Session.fail_generation active "turn-1" with
  | Ok session -> assert_equal "failure clears active generation" None session.generation
  | Error _ -> failwith "expected failure transition"

let () =
  test_starts_one_generation ();
  test_completes_matching_turn ();
  test_marks_cancellation_before_interrupt ();
  test_rejects_wrong_completion ();
  test_failure_clears_matching_turn ()
