open Codex_client

let assert_equal label expected actual =
  if expected <> actual then failwith label

let thread = Thread.{ id = "thread-1" }
let turn = Turn.{ id = "turn-1" }

let notification method_ params =
  Client.Notification Codex_protocol.JsonRpc.{ method_; params = Some params }

let test_routes_matching_delta () =
  assert_equal "assistant delta is routed to the active generation"
    (Ok (Generation.Routed (Generation.Delta { item_id = "item-1"; delta = "{" })))
    (Generation.route thread turn (notification "item/agentMessage/delta" (`Assoc [
      ("threadId", `String "thread-1");
      ("turnId", `String "turn-1");
      ("itemId", `String "item-1");
      ("delta", `String "{");
    ])))

let test_ignores_other_turns () =
  assert_equal "other turns cannot update this generation"
    (Ok Generation.Ignored)
    (Generation.route thread turn (notification "item/agentMessage/delta" (`Assoc [
      ("threadId", `String "thread-1");
      ("turnId", `String "turn-2");
      ("itemId", `String "item-1");
      ("delta", `String "{");
    ])))

let test_routes_completion () =
  assert_equal "completion is correlated by thread and turn"
    (Ok (Generation.Routed (Generation.Turn_finished Generation.Completed)))
    (Generation.route thread turn (notification "turn/completed" (`Assoc [
      ("threadId", `String "thread-1");
      ("turn", `Assoc [
        ("id", `String "turn-1");
        ("status", `String "completed");
      ]);
    ])))

let test_routes_failed_completion () =
  assert_equal "failed turns are routed with their server error"
    (Ok (Generation.Routed (Generation.Turn_finished (Generation.Failed "model failed"))))
    (Generation.route thread turn (notification "turn/completed" (`Assoc [
      ("threadId", `String "thread-1");
      ("turn", `Assoc [
        ("id", `String "turn-1");
        ("status", `String "failed");
        ("error", `Assoc [("message", `String "model failed")]);
      ]);
    ])))

let test_rejects_duplicate_completion () =
  assert_equal "a turn completes once"
    (Error Generation.Duplicate_completion)
    (Generation.advance Generation.Finished
      (Generation.Routed (Generation.Turn_finished Generation.Completed)))

let test_reports_child_exit_during_generation () =
  assert_equal "a child exit fails an active generation"
    (Error Generation.Child_exited)
    (Generation.child_exited Generation.Streaming)

let test_rejects_malformed_delta () =
  assert_equal "matching malformed deltas are not accepted"
    (Error (Generation.Invalid_notification "missing field: delta"))
    (Generation.route thread turn (notification "item/agentMessage/delta" (`Assoc [
      ("threadId", `String "thread-1");
      ("turnId", `String "turn-1");
      ("itemId", `String "item-1");
    ])))

let () =
  test_routes_matching_delta ();
  test_ignores_other_turns ();
  test_routes_completion ();
  test_routes_failed_completion ();
  test_rejects_duplicate_completion ();
  test_reports_child_exit_during_generation ();
  test_rejects_malformed_delta ()
