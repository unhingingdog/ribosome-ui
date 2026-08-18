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
    (Ok (Generation.Routed Generation.Completed))
    (Generation.route thread turn (notification "turn/completed" (`Assoc [
      ("threadId", `String "thread-1");
      ("turn", `Assoc [("id", `String "turn-1")]);
    ])))

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
  test_rejects_malformed_delta ()
