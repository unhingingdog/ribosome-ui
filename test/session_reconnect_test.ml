open Ribosome_session

let assert_equal label expected actual =
  if expected <> actual then failwith label

let test_reconnect_resends_current_state () =
  let session = Session.create "session-1" in
  match Session.reconnect session "connection-1" with
  | Ok (session, Session.Session_state { revision; tree }) ->
    assert_equal "reconnect joins the session" ["connection-1"] session.connections;
    assert_equal "reconnect receives the latest revision" 0 revision;
    assert_equal "reconnect receives the complete current tree" None tree
  | Error _ | Ok (_, Session.Template_updated _) -> failwith "expected session state"

let () = test_reconnect_resends_current_state ()
