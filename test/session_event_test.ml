open Ribosome_session

let assert_equal label expected actual =
  if expected <> actual then failwith label

let tree = Ribosome_core.Types.Submittable Templates.Submittable.{
  kind = "submittable";
  id = "profile";
  value = [FieldInput Templates.Input.{ kind = "input"; id = "name"; value = Some (String "") }];
  button = Some Templates.Button.{ kind = "button"; id = "save"; label = "Save"; action = Submit; disabled = None };
}

let session = Session.{ (create "session-1") with tree = Some tree; lifecycle = Ready }

let event event_id base_revision event = Dream_protocol.ClientMessage.Component_event {
  session_id = "session-1";
  event_id;
  base_revision;
  event;
}

let test_accepts_form_submission () =
  let message = event "event-1" 0 (Submit {
    id = "profile";
    values = [("name", Ribosome_core.Types.String "Alice")];
  }) in
  assert_equal "valid form events retain their semantic payload"
    (Ok ({ session with recent_event_ids = ["event-1"] }, Session.{
      event_id = "event-1";
      event = Submit { id = "profile"; values = [("name", Ribosome_core.Types.String "Alice")] };
    }))
    (Session.reduce_event session message)

let test_rejects_stale_revision () =
  assert_equal "events apply only to their observed revision"
    (Error Session.Stale_revision)
    (Session.reduce_event session (event "event-1" 1 (Click { id = "save" })))

let test_accepts_button_click_and_field_change () =
  assert_equal "button IDs resolve within forms"
    (Ok ({ session with recent_event_ids = ["event-1"] }, Session.{ event_id = "event-1"; event = Click { id = "save" } }))
    (Session.reduce_event session (event "event-1" 0 (Click { id = "save" })));
  assert_equal "field IDs resolve within forms"
    (Ok ({ session with recent_event_ids = ["event-2"] }, Session.{
      event_id = "event-2";
      event = Change { id = "name"; value = Ribosome_core.Types.String "Alice" };
    }))
    (Session.reduce_event session (event "event-2" 0
      (Change { id = "name"; value = Ribosome_core.Types.String "Alice" })))

let test_rejects_unknown_component () =
  assert_equal "events cannot target arbitrary model-supplied IDs"
    (Error (Session.Unknown_component "missing"))
    (Session.reduce_event session (event "event-1" 0 (Click { id = "missing" })))

let test_rejects_duplicate_event_ids () =
  let accepted, _ = match Session.reduce_event session (event "event-1" 0 (Click { id = "save" })) with
    | Ok result -> result
    | Error _ -> failwith "expected first event"
  in
  assert_equal "event IDs are idempotency keys"
    (Error Session.Duplicate_event_id)
    (Session.reduce_event accepted (event "event-1" 0 (Click { id = "save" })))

let () =
  test_accepts_form_submission ();
  test_rejects_stale_revision ();
  test_accepts_button_click_and_field_change ();
  test_rejects_unknown_component ();
  test_rejects_duplicate_event_ids ()
