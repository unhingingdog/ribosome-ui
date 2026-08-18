open Ribosome_session

let assert_equal label expected actual =
  if expected <> actual then failwith label

let test_creates_uninitialized_session () =
  assert_equal "a new session has no generated state"
    Session.{
      id = "session-1";
      initial_prompt = "Initial request";
      thread = None;
      tree = None;
      revision = 0;
      stream = Ribosome_incremental.Incremental.create None;
      connections = [];
      recent_event_ids = [];
      generation = None;
      lifecycle = Starting;
    }
    (Session.create ~initial_prompt:"Initial request" "session-1")

let test_attaches_one_codex_thread () =
  let session = Session.create ~initial_prompt:"Initial request" "session-1" in
  let thread = Codex_client.Thread.{ id = "thread-1" } in
  assert_equal "thread ownership belongs to the Dream session"
    (Ok Session.{
      id = "session-1";
      initial_prompt = "Initial request";
      thread = Some thread;
      tree = None;
      revision = 0;
      stream = Ribosome_incremental.Incremental.create None;
      connections = [];
      recent_event_ids = [];
      generation = None;
      lifecycle = Ready;
    })
    (Session.attach_thread session thread)

let test_connection_membership_is_idempotent () =
  let session = Session.create ~initial_prompt:"Initial request" "session-1" in
  let connected = match Session.connect session "connection-1" with
    | Ok session -> session
    | Error _ -> failwith "expected connection"
  in
  assert_equal "a reconnect does not duplicate membership"
    (Ok connected)
    (Session.connect connected "connection-1")

let test_closing_drops_connections () =
  let session = Session.create ~initial_prompt:"Initial request" "session-1" in
  let session = match Session.connect session "connection-1" with
    | Ok session -> session
    | Error _ -> failwith "expected connection"
  in
  assert_equal "closed sessions retain no protocol connections"
    Session.{ session with lifecycle = Closed; connections = [] }
    (Session.close session)

let () =
  test_creates_uninitialized_session ();
  test_attaches_one_codex_thread ();
  test_connection_membership_is_idempotent ();
  test_closing_drops_connections ()
