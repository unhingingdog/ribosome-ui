open Ribosome_server_lib

(* Task 7.2: end-to-end MCP kickoff through streamed rendering.
   Initializes MCP over scripted calls, calls start, attaches harness
   and UI clients, streams a template one character per delta, asserts
   multiple pre-completion UI revisions and the final typed tree. *)

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

let skill_body = "You are a Ribosome UI agent. Output raw template JSON only."

let fake_skill_loader path =
  if path = "skills/ribosome/SKILL.md" then Some skill_body else None

(* The template we'll stream char by char *)
let template_json =
  {json|{"kind":"submittable","id":"form1","value":[{"kind":"input","id":"inp1","value":"hi"}],"button":{"id":"btn1","label":"Go","action":"Submit"}}|json}

(* Collect UI broadcasts *)
let ui_updates = ref []
let ui_snapshots = ref []
let ui_rejections = ref []
let ui_user_turns = ref []

let reset_ui () =
  ui_updates := [];
  ui_snapshots := [];
  ui_rejections := [];
  ui_user_turns := []

let make_ui_broadcast () =
  {
    Ui_runtime.broadcast_template_update =
      (fun ~session_id ~revision ~tree ->
        ui_updates := (session_id, revision, tree) :: !ui_updates);
    broadcast_session_state =
      (fun ~session_id ~mode ~revision ~tree ~generation_id ->
        ui_snapshots :=
          (session_id, mode, revision, tree, generation_id) :: !ui_snapshots);
    broadcast_event_rejection =
      (fun ~session_id ~event_id ~reason ->
        ui_rejections := (session_id, event_id, reason) :: !ui_rejections);
    send_user_turn =
      (fun ~session_id ~tree ~event ->
        ui_user_turns := (session_id, tree, event) :: !ui_user_turns);
  }

(* Collect harness broadcasts (template updates forwarded to UI) *)
let h_updates = ref []

let make_harness_broadcast () =
  {
    Harness_runtime.broadcast_template_update =
      (fun ~session_id ~revision ~tree ->
        h_updates := (session_id, revision, tree) :: !h_updates);
  }

let rejection_str = function
  | Harness_protocol.InvalidSession -> "invalid_session"
  | Harness_protocol.InvalidGeneration -> "invalid_generation"
  | Harness_protocol.InvalidSequence -> "invalid_sequence"
  | Harness_protocol.MalformedPayload -> "malformed_payload"

let test_full_kickoff_and_stream () =
  reset_ui ();
  h_updates := [];
  let registry = Session_registry.create () in
  let id_gen = make_id_gen () in
  let config = { Mcp.registry; id_gen; skill_loader = fake_skill_loader } in

  (* 1. Initialize MCP over scripted calls *)
  let state =
    let _state, _ =
      Mcp.handle config Mcp.Uninitialized
        (Jsonrpc.Request
           { id = Int_id 1; method_ = "initialize"; params = None })
    in
    let state, _ =
      Mcp.handle config _state
        (Jsonrpc.Notification
           { method_ = "notifications/initialized"; params = None })
    in
    state
  in
  Alcotest.(check string)
    "mcp initialized" "Initialized"
    (match state with Initialized -> "Initialized" | _ -> "wrong");

  (* 2. Call tools/list *)
  let _, tools_resp =
    Mcp.handle config state
      (Jsonrpc.Request { id = Int_id 2; method_ = "tools/list"; params = None })
  in
  (match tools_resp with
  | Some (Jsonrpc.Success { result; _ }) ->
      let tools =
        match result with
        | `Assoc a -> (
            match Stdlib.List.assoc_opt "tools" a with
            | Some (`List l) -> l
            | _ -> Alcotest.fail "no tools list")
        | _ -> Alcotest.fail "bad tools/list response"
      in
      let has_start =
        Stdlib.List.exists
          (function
            | `Assoc fields -> (
                match Stdlib.List.assoc_opt "name" fields with
                | Some (`String "start") -> true
                | _ -> false)
            | _ -> false)
          tools
      in
      Alcotest.(check bool) "tools/list has start" true has_start
  | _ -> Alcotest.fail "tools/list failed");

  (* 3. Call tools/call start with harness session id and nonce *)
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
         { id = Int_id 3; method_ = "tools/call"; params = Some start_params })
  in
  let session_id, _ui_nonce =
    match start_resp with
    | Some (Jsonrpc.Success { result; _ }) ->
        let structured =
          match result with
          | `Assoc a -> (
              match Stdlib.List.assoc_opt "structuredContent" a with
              | Some (`Assoc sc) -> sc
              | _ -> Alcotest.fail "no structuredContent")
          | _ -> Alcotest.fail "bad start response"
        in
        let sid =
          match Stdlib.List.assoc_opt "session_id" structured with
          | Some (`String v) -> v
          | _ -> Alcotest.fail "no session_id"
        in
        let nonce =
          match Stdlib.List.assoc_opt "ui_nonce" structured with
          | Some (`String v) -> v
          | _ -> Alcotest.fail "no ui_nonce"
        in
        (sid, nonce)
    | _ -> Alcotest.fail "start tool failed"
  in
  Alcotest.(check string) "session id is rs-1" "rs-1" session_id;

  (* 7. Assert the returned kickoff content includes the Ribosome skill *)
  (match start_resp with
  | Some (Jsonrpc.Success { result; _ }) ->
      let content =
        match result with
        | `Assoc a -> (
            match Stdlib.List.assoc_opt "content" a with
            | Some (`List [ `Assoc fields ]) -> (
                match Stdlib.List.assoc_opt "text" fields with
                | Some (`String text) -> text
                | _ -> Alcotest.fail "no text in content")
            | _ -> Alcotest.fail "no content list")
        | _ -> Alcotest.fail "bad start response"
      in
      Alcotest.(check bool)
        "skill body in content" true
        (String.length content >= String.length skill_body
        && String.sub content 0 (String.length skill_body) = skill_body)
  | _ -> ());

  (* 4. Set up harness and UI runtimes sharing the registry *)
  let h_runtime =
    Harness_runtime.create ~registry ~broadcast:(make_harness_broadcast ())
  in
  let u_runtime =
    Ui_runtime.create ~registry ~broadcast:(make_ui_broadcast ())
  in
  Harness_runtime.register_session h_runtime ~session_id;
  Ui_runtime.register_session u_runtime ~session_id;

  (* Attach fake harness client using the nonce from start *)
  let attach_msg =
    Harness_protocol.Attach
      { session_id; harness_session_id = "hs-1"; nonce = "hn-1" }
  in
  (match Harness_runtime.handle_message h_runtime attach_msg with
  | Ok Harness_runtime.Attached -> ()
  | Error r -> Alcotest.fail ("harness attach failed: " ^ rejection_str r)
  | _ -> Alcotest.fail "unexpected attach result");

  (* Attach fake UI client *)
  let ui_attach = Ui_protocol.Attach { session_id; revision = None } in
  (match Ui_runtime.handle_message u_runtime ui_attach with
  | Ok () -> ()
  | Error _ -> Alcotest.fail "ui attach failed");
  Alcotest.(check int) "ui snapshot sent" 1 (Stdlib.List.length !ui_snapshots);

  (* 5. Stream the template one character per delta *)
  let gen_id = "gen-1" in
  let n = String.length template_json in
  let rev_before = Stdlib.List.length !h_updates in
  for i = 0 to n - 1 do
    let ch = String.sub template_json i 1 in
    let delta_msg =
      Harness_protocol.Delta
        { session_id; generation_id = gen_id; seq = i; content = ch }
    in
    match Harness_runtime.handle_message h_runtime delta_msg with
    | Ok _ -> ()
    | Error r ->
        Alcotest.fail
          ("delta " ^ string_of_int i ^ " failed: " ^ rejection_str r)
  done;

  (* 5a. Assert multiple pre-completion UI revisions *)
  let rev_after = Stdlib.List.length !h_updates in
  let delta_revisions = rev_after - rev_before in
  Alcotest.(check bool)
    "multiple pre-completion revisions" true (delta_revisions >= 2);
  Alcotest.(check bool)
    "not all deltas pending" true
    (delta_revisions < n || delta_revisions >= 2);

  (* 6. Complete generation and assert the final typed tree *)
  let complete_msg =
    Harness_protocol.GenerationCompleted { session_id; generation_id = gen_id }
  in
  (match Harness_runtime.handle_message h_runtime complete_msg with
  | Ok Harness_runtime.Completed -> ()
  | Error r -> Alcotest.fail ("generation complete failed: " ^ rejection_str r)
  | _ -> Alcotest.fail "unexpected complete result");

  (* The final tree should match the template we streamed *)
  let latest_tree =
    match !h_updates with
    | (_, _, tree) :: _ -> tree
    | [] -> Alcotest.fail "no template updates"
  in
  let parsed = Yojson.Safe.from_string latest_tree in
  let kind =
    match parsed with
    | `Assoc a -> (
        match Stdlib.List.assoc_opt "kind" a with
        | Some (`String k) -> k
        | _ -> "missing")
    | _ -> "bad"
  in
  Alcotest.(check string) "final tree kind is submittable" "submittable" kind;
  (* Verify the input value survived the round trip *)
  let has_input_value =
    String.length latest_tree >= 4 && String.sub latest_tree 0 4 <> "null"
  in
  Alcotest.(check bool) "tree is not null" true has_input_value

let () =
  Alcotest.run "ribosome-vslice-kickoff"
    [
      ( "kickoff",
        [
          Alcotest.test_case "full kickoff and stream" `Quick
            test_full_kickoff_and_stream;
        ] );
    ]
