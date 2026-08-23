open Ribosome_server_lib

(* Task 7.3: exercise submission and second generation.
   Builds on the kickoff test: after the first generation completes,
   the UI client submits values, the harness receives a user turn,
   a second generation streams a patch, reconciliation preserves
   unaffected regions, and a reconnecting UI client gets the
   authoritative tree. *)

let make_id_gen () =
  let n = ref 0 in
  {
    Session_registry.gen_session_id =
      (fun () ->
        incr n;
        "rs-" ^ string_of_int !n);
    gen_ui_nonce =
      (fun () ->
        incr n;
        "ui-nonce-" ^ string_of_int !n);
  }

let skill_body = "You are a Ribosome UI agent."

let fake_skill_loader path =
  if path = "skills/ribosome/SKILL.md" then Some skill_body else None

(* First generation: a container with a submittable form and a text child *)
let template_v1 =
  {json|{"kind":"container","id":"root","direction":"Vertical","children":[{"kind":"submittable","id":"form1","value":[{"kind":"input","id":"inp1","value":""}],"button":{"id":"btn1","label":"Go","action":"Submit"}},{"kind":"text","id":"txt1","text_type":"Paragraph","value":"Hello"}]}|json}

(* Second generation: patch the text child only, keep the form *)
let template_v2 =
  {json|{"kind":"container","id":"root","direction":"Vertical","children":[{"kind":"submittable","id":"form1","value":[{"kind":"input","id":"inp1","value":""}],"button":{"id":"btn1","label":"Go","action":"Submit"}},{"kind":"text","id":"txt1","text_type":"Paragraph","value":"World"}]}|json}

(* Collected broadcasts *)
let ui_updates = ref []
let ui_snapshots = ref []
let ui_rejections = ref []
let ui_user_turns = ref []
let h_updates = ref []
let client_rev = ref 0
let client_tree = ref None
let client_connected = ref false

let reset_all () =
  ui_updates := [];
  ui_snapshots := [];
  ui_rejections := [];
  ui_user_turns := [];
  h_updates := [];
  client_rev := 0;
  client_tree := None;
  client_connected := false

let make_ui_broadcast () =
  {
    Ui_runtime.broadcast_template_update =
      (fun ~session_id:_ ~revision ~tree ->
        ui_updates := (revision, tree) :: !ui_updates;
        client_rev := revision;
        client_tree := Some tree);
    broadcast_session_state =
      (fun ~session_id:_ ~mode:_ ~revision ~tree ~generation_id:_ ->
        ui_snapshots := (revision, tree) :: !ui_snapshots;
        client_rev := revision;
        client_tree := tree;
        client_connected := true);
    broadcast_event_rejection =
      (fun ~session_id:_ ~event_id:_ ~reason:_ ->
        ui_rejections := true :: !ui_rejections);
    send_user_turn =
      (fun ~session_id ~tree ~event ->
        ui_user_turns := (session_id, tree, event) :: !ui_user_turns);
  }

let make_harness_broadcast () =
  {
    Harness_runtime.broadcast_template_update =
      (fun ~session_id:_ ~revision ~tree ->
        h_updates := (revision, tree) :: !h_updates);
  }

let rejection_str = function
  | Harness_protocol.InvalidSession -> "invalid_session"
  | Harness_protocol.InvalidGeneration -> "invalid_generation"
  | Harness_protocol.InvalidSequence -> "invalid_sequence"
  | Harness_protocol.MalformedPayload -> "malformed_payload"

let contains_substring s sub =
  let n = String.length s in
  let m = String.length sub in
  if m = 0 then true
  else if m > n then false
  else
    let rec loop i =
      if i + m > n then false
      else if String.sub s i m = sub then true
      else loop (i + 1)
    in
    loop 0

(* Stream a template char-by-char through the harness runtime *)
let stream_template ~h_runtime ~session_id ~gen_id ~template =
  let n = String.length template in
  for i = 0 to n - 1 do
    let ch = String.sub template i 1 in
    let delta_msg =
      Harness_protocol.Delta
        { session_id; generation_id = gen_id; seq = i; content = ch }
    in
    match Harness_runtime.handle_message h_runtime delta_msg with
    | Ok _ -> ()
    | Error r ->
        Alcotest.fail
          ("delta " ^ string_of_int i ^ " failed: " ^ rejection_str r)
  done

let complete_generation ~h_runtime ~session_id ~gen_id =
  let msg =
    Harness_protocol.GenerationCompleted { session_id; generation_id = gen_id }
  in
  match Harness_runtime.handle_message h_runtime msg with
  | Ok Harness_runtime.Completed -> ()
  | Error r -> Alcotest.fail ("complete failed: " ^ rejection_str r)
  | _ -> Alcotest.fail "unexpected complete result"

let sync_session ~src ~dst ~session_id =
  match src ~session_id with
  | None -> Alcotest.fail "no session to sync"
  | Some session -> dst ~session_id session

let event_id_counter = ref 0

let next_event_id () =
  incr event_id_counter;
  "evt-" ^ string_of_int !event_id_counter

let send_ui_event ~u_runtime ~session_id ~target_id ~kind ~value =
  let msg =
    Ui_protocol.ComponentEvent
      {
        session_id;
        revision = !client_rev;
        event_id = next_event_id ();
        target_id;
        kind;
        value;
      }
  in
  match Ui_runtime.handle_message u_runtime msg with
  | Ok () -> ()
  | Error (Ui_runtime.EventError s) -> Alcotest.fail ("event error: " ^ s)
  | Error _ -> Alcotest.fail "event failed"

let test_two_turn_loop () =
  reset_all ();
  let registry = Session_registry.create () in
  let id_gen = make_id_gen () in
  let config = { Mcp.registry; id_gen; skill_loader = fake_skill_loader } in

  (* Initialize MCP and call start *)
  let state =
    let s, _ =
      Mcp.handle config Mcp.Uninitialized
        (Jsonrpc.Request
           { id = Int_id 1; method_ = "initialize"; params = None })
    in
    let s, _ =
      Mcp.handle config s
        (Jsonrpc.Notification
           { method_ = "notifications/initialized"; params = None })
    in
    s
  in
  let start_params =
    `Assoc
      [
        ("name", `String "start");
        ( "arguments",
          `Assoc
            [
              ("_harness_session_id", `String "hs-1"); ("_nonce", `String "hn-1");
            ] );
      ]
  in
  let _, start_resp =
    Mcp.handle config state
      (Jsonrpc.Request
         { id = Int_id 2; method_ = "tools/call"; params = Some start_params })
  in
  let session_id =
    match start_resp with
    | Some (Jsonrpc.Success { result; _ }) -> (
        match result with
        | `Assoc a -> (
            match Stdlib.List.assoc_opt "structuredContent" a with
            | Some (`Assoc sc) -> (
                match Stdlib.List.assoc_opt "session_id" sc with
                | Some (`String s) -> s
                | _ -> Alcotest.fail "no session_id")
            | _ -> Alcotest.fail "no structuredContent")
        | _ -> Alcotest.fail "bad start response")
    | _ -> Alcotest.fail "start failed"
  in

  (* Set up runtimes sharing the registry *)
  let h_runtime =
    Harness_runtime.create ~registry ~broadcast:(make_harness_broadcast ())
  in
  let u_runtime =
    Ui_runtime.create ~registry ~broadcast:(make_ui_broadcast ())
  in
  Harness_runtime.register_session h_runtime ~session_id;
  Ui_runtime.register_session u_runtime ~session_id;

  (* Attach harness *)
  let attach_msg =
    Harness_protocol.Attach
      { session_id; harness_session_id = "hs-1"; nonce = "hn-1" }
  in
  (match Harness_runtime.handle_message h_runtime attach_msg with
  | Ok Harness_runtime.Attached -> ()
  | _ -> Alcotest.fail "harness attach failed");

  (* === First generation: stream template_v1 === *)
  let gen1 = "gen-1" in
  stream_template ~h_runtime ~session_id ~gen_id:gen1 ~template:template_v1;
  complete_generation ~h_runtime ~session_id ~gen_id:gen1;

  (* Sync the completed session from harness to UI *)
  sync_session
    ~src:(Harness_runtime.get_session h_runtime)
    ~dst:(Ui_runtime.put_session u_runtime)
    ~session_id;

  (* Attach UI client (after gen1 so the tree exists) *)
  let ui_attach = Ui_protocol.Attach { session_id; revision = None } in
  (match Ui_runtime.handle_message u_runtime ui_attach with
  | Ok () -> ()
  | Error _ -> Alcotest.fail "ui attach failed");
  Alcotest.(check bool) "ui client connected" true !client_connected;
  Alcotest.(check bool) "ui client has tree" true (!client_tree <> None);

  (* === Step 1: Submit values from the protocol UI client === *)
  send_ui_event ~u_runtime ~session_id ~target_id:"inp1"
    ~kind:Ui_protocol.Change
    ~value:(Some (`String "hello"));
  Alcotest.(check bool) "revision bumped after change" true (!client_rev >= 2);

  send_ui_event ~u_runtime ~session_id ~target_id:"form1"
    ~kind:Ui_protocol.Submit ~value:None;

  (* === Step 2: Assert the harness receives one full-tree user turn === *)
  Alcotest.(check int) "one user turn" 1 (Stdlib.List.length !ui_user_turns);
  let ut_session, ut_tree, _ut_event =
    match !ui_user_turns with
    | [ x ] -> x
    | _ -> Alcotest.fail "expected exactly one user turn"
  in
  Alcotest.(check string) "user turn session" session_id ut_session;
  Alcotest.(check bool)
    "user turn tree contains form1" true
    (contains_substring ut_tree "form1");
  Alcotest.(check bool)
    "user turn tree contains hello" true
    (contains_substring ut_tree "hello");

  (* === Step 3: Start a second generation === *)
  sync_session
    ~src:(Ui_runtime.get_session u_runtime)
    ~dst:(Harness_runtime.put_session h_runtime)
    ~session_id;
  let gen2 = "gen-2" in

  (* === Step 4: Stream a subtree patch one character per delta === *)
  stream_template ~h_runtime ~session_id ~gen_id:gen2 ~template:template_v2;
  complete_generation ~h_runtime ~session_id ~gen_id:gen2;

  (* === Step 5: Assert reconciliation preserves unaffected root regions === *)
  let latest_tree =
    match !h_updates with
    | (_, tree) :: _ -> tree
    | [] -> Alcotest.fail "no harness updates after gen2"
  in
  Alcotest.(check bool)
    "gen2 tree has form1 preserved" true
    (contains_substring latest_tree "form1");
  Alcotest.(check bool)
    "gen2 tree has btn1 preserved" true
    (contains_substring latest_tree "btn1");
  Alcotest.(check bool)
    "gen2 tree has updated text World" true
    (contains_substring latest_tree "World");

  (* === Step 6: Reconnect UI client and assert authoritative tree === *)
  sync_session
    ~src:(Harness_runtime.get_session h_runtime)
    ~dst:(Ui_runtime.put_session u_runtime)
    ~session_id;

  (* Disconnect *)
  let disconnect_msg = Ui_protocol.Disconnect { session_id } in
  (match Ui_runtime.handle_message u_runtime disconnect_msg with
  | Ok () -> ()
  | Error _ -> Alcotest.fail "disconnect failed");
  client_connected := false;

  (* Reconnect from known revision *)
  let reconnect_msg =
    Ui_protocol.Attach { session_id; revision = Some !client_rev }
  in
  (match Ui_runtime.handle_message u_runtime reconnect_msg with
  | Ok () -> ()
  | Error _ -> Alcotest.fail "reconnect failed");
  Alcotest.(check bool) "reconnected" true !client_connected;
  Alcotest.(check bool)
    "reconnected tree has World" true
    (match !client_tree with
    | Some t -> contains_substring t "World"
    | None -> false);
  Alcotest.(check bool)
    "reconnected tree has form1" true
    (match !client_tree with
    | Some t -> contains_substring t "form1"
    | None -> false)

let () =
  Alcotest.run "ribosome-vslice-two-turn"
    [
      ( "two-turn",
        [
          Alcotest.test_case "complete two-turn loop" `Quick test_two_turn_loop;
        ] );
    ]
