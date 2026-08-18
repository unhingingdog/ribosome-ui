open Telomere

let assert_equal label expected actual =
  if expected <> actual then failwith label

let test_completes_open_object () =
  let output, state = Processor.feed (Processor.create_processor ()) "{" in
  assert_equal "open object is closable" (Processor.Completion "}") output;
  assert_equal "processor stores object buffer" "{" state.Processor.buffer

let test_waits_for_open_key () =
  let output, _ = Processor.feed (Processor.create_processor ()) "{\"label" in
  assert_equal "open key is pending" Processor.Pending output

let test_preserves_state_between_chunks () =
  let _, state = Processor.feed (Processor.create_processor ()) "{\"label\":\"" in
  let output, state = Processor.feed state "ok\"" in
  assert_equal "closed value completes object" (Processor.Completion "}") output;
  assert_equal "processor appends chunks" "{\"label\":\"ok\"" state.Processor.buffer

let test_corruption_is_terminal () =
  let output, state = Processor.feed (Processor.create_processor ()) "]" in
  assert_equal "unexpected closer corrupts" Processor.Corrupted output;
  let output, _ = Processor.feed state "{" in
  assert_equal "corruption remains terminal" Processor.Corrupted output

let () =
  test_completes_open_object ();
  test_waits_for_open_key ();
  test_preserves_state_between_chunks ();
  test_corruption_is_terminal ()
