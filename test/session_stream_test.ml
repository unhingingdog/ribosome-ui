open Ribosome_session

let assert_equal label expected actual =
  if expected <> actual then failwith label

let text content = Ribosome_core.Types.Text Templates.Text.{
  kind = "text";
  id = "title";
  text_type = Paragraph;
  content;
}

let test_commits_valid_streamed_template () =
  let session = Session.create "session-1" in
  match Session.feed_delta session
    "{\"kind\":\"text\",\"id\":\"title\",\"text_type\":\"Paragraph\",\"value\":\"After\"}" with
  | Ok (session, Some (Session.Template_updated { revision; tree })) ->
    assert_equal "valid template increments the session revision" 1 revision;
    assert_equal "valid template becomes authoritative" (Some (text "After")) session.tree;
    assert_equal "effect contains the complete reconciled tree" (text "After") tree
  | Ok (_, None) | Error _ -> failwith "expected template update"

let test_preserves_state_for_invalid_streamed_template () =
  let session = Session.create "session-1" in
  let session, _ = match Session.feed_delta session
    "{\"kind\":\"text\",\"id\":\"title\",\"text_type\":\"Paragraph\",\"value\":\"Before\"}" with
    | Ok result -> result
    | Error _ -> failwith "expected initial template"
  in
  match Session.feed_delta session "{\"kind\":\"unknown\"}" with
  | Ok (next, None) ->
    assert_equal "invalid output keeps the last valid tree" session.tree next.tree;
    assert_equal "invalid output does not advance the revision" session.revision next.revision
  | Ok (_, Some _) | Error _ -> failwith "expected rejected template"

let () =
  test_commits_valid_streamed_template ();
  test_preserves_state_for_invalid_streamed_template ()
