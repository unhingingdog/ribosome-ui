open Ribosome_server_lib

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

let make_registry () =
  let registry = Session_registry.create () in
  let _ =
    Session_registry.start ~id_gen:(make_id_gen ()) ~registry
      ~harness_session_id:"hs-1" ~harness_nonce:"hn-1" ()
  in
  registry

let broadcasts = ref []

let make_broadcast () =
  {
    Harness_runtime.broadcast_template_update =
      (fun ~session_id ~revision ~tree ->
        broadcasts := (session_id, revision, tree) :: !broadcasts);
  }

let make_runtime () =
  let registry = make_registry () in
  let broadcast = make_broadcast () in
  let runtime = Harness_runtime.create ~registry ~broadcast in
  Harness_runtime.register_session runtime ~session_id:"rs-1";
  runtime

let reset () = broadcasts := []

let test_attach_success () =
  reset ();
  let runtime = make_runtime () in
  let msg =
    Harness_protocol.Attach
      { session_id = "rs-1"; harness_session_id = "hs-1"; nonce = "hn-1" }
  in
  match Harness_runtime.handle_message runtime msg with
  | Ok Harness_runtime.Attached -> ()
  | _ -> Alcotest.fail "expected Attached"

let test_attach_bad_nonce () =
  reset ();
  let runtime = make_runtime () in
  let msg =
    Harness_protocol.Attach
      { session_id = "rs-1"; harness_session_id = "hs-1"; nonce = "wrong" }
  in
  match Harness_runtime.handle_message runtime msg with
  | Error Harness_protocol.InvalidSession -> ()
  | _ -> Alcotest.fail "expected InvalidSession"

let test_attach_bad_session () =
  reset ();
  let runtime = make_runtime () in
  let msg =
    Harness_protocol.Attach
      { session_id = "nope"; harness_session_id = "hs-1"; nonce = "hn-1" }
  in
  match Harness_runtime.handle_message runtime msg with
  | Error Harness_protocol.InvalidSession -> ()
  | _ -> Alcotest.fail "expected InvalidSession"

(* Feed a complete JSON template one char at a time. *)
let template_json =
  {json|{"kind":"text","id":"t1","text_type":"Paragraph","value":"hi"}|json}

let test_one_char_deltas_produce_updates () =
  reset ();
  let runtime = make_runtime () in
  let chars =
    List.init (String.length template_json) (String.get template_json)
  in
  let _ =
    Stdlib.List.mapi
      (fun i c ->
        let msg =
          Harness_protocol.Delta
            {
              session_id = "rs-1";
              generation_id = "gen-1";
              seq = i;
              content = String.make 1 c;
            }
        in
        Harness_runtime.handle_message runtime msg)
      chars
  in
  (* Should have broadcast at least one template update (when JSON completes) *)
  Alcotest.(check bool)
    "at least one broadcast" true
    (Stdlib.List.length !broadcasts > 0);
  (* The last broadcast should have the full tree *)
  match !broadcasts with
  | (_, rev, tree) :: _ ->
      Alcotest.(check bool) "revision incremented" true (rev > 0);
      Alcotest.(check bool)
        "tree is valid json" true
        (try
           let _ = Yojson.Safe.from_string tree in
           true
         with _ -> false)
  | [] -> ()

let test_delta_wrong_session () =
  reset ();
  let runtime = make_runtime () in
  let msg =
    Harness_protocol.Delta
      { session_id = "nope"; generation_id = "gen-1"; seq = 1; content = "{" }
  in
  match Harness_runtime.handle_message runtime msg with
  | Error Harness_protocol.InvalidSession -> ()
  | _ -> Alcotest.fail "expected InvalidSession"

let test_delta_out_of_order_seq () =
  reset ();
  let runtime = make_runtime () in
  let msg1 =
    Harness_protocol.Delta
      { session_id = "rs-1"; generation_id = "gen-1"; seq = 0; content = "{" }
  in
  let msg3 =
    Harness_protocol.Delta
      { session_id = "rs-1"; generation_id = "gen-1"; seq = 2; content = "}" }
  in
  let _ = Harness_runtime.handle_message runtime msg1 in
  match Harness_runtime.handle_message runtime msg3 with
  | Error Harness_protocol.InvalidSequence -> ()
  | _ -> Alcotest.fail "expected InvalidSequence for out-of-order seq"

let test_generation_completed () =
  reset ();
  let runtime = make_runtime () in
  let _ =
    Harness_runtime.handle_message runtime
      (Harness_protocol.Delta
         {
           session_id = "rs-1";
           generation_id = "gen-1";
           seq = 0;
           content = template_json;
         })
  in
  let msg =
    Harness_protocol.GenerationCompleted
      { session_id = "rs-1"; generation_id = "gen-1" }
  in
  match Harness_runtime.handle_message runtime msg with
  | Ok Harness_runtime.Completed -> ()
  | _ -> Alcotest.fail "expected Completed"

let test_generation_failed () =
  reset ();
  let runtime = make_runtime () in
  let _ =
    Harness_runtime.handle_message runtime
      (Harness_protocol.Delta
         {
           session_id = "rs-1";
           generation_id = "gen-1";
           seq = 0;
           content = "{";
         })
  in
  let msg =
    Harness_protocol.GenerationFailed
      { session_id = "rs-1"; generation_id = "gen-1"; reason = Some "error" }
  in
  match Harness_runtime.handle_message runtime msg with
  | Ok Harness_runtime.Completed -> ()
  | _ -> Alcotest.fail "expected Completed"

let test_generation_wrong_id () =
  reset ();
  let runtime = make_runtime () in
  let _ =
    Harness_runtime.handle_message runtime
      (Harness_protocol.Delta
         {
           session_id = "rs-1";
           generation_id = "gen-1";
           seq = 1;
           content = "{";
         })
  in
  let msg =
    Harness_protocol.GenerationCompleted
      { session_id = "rs-1"; generation_id = "gen-wrong" }
  in
  match Harness_runtime.handle_message runtime msg with
  | Error Harness_protocol.InvalidGeneration -> ()
  | _ -> Alcotest.fail "expected InvalidGeneration"

let () =
  Alcotest.run "ribosome-harness-runtime"
    [
      ( "attach",
        [
          Alcotest.test_case "attach success" `Quick test_attach_success;
          Alcotest.test_case "attach bad nonce" `Quick test_attach_bad_nonce;
          Alcotest.test_case "attach bad session" `Quick test_attach_bad_session;
        ] );
      ( "deltas",
        [
          Alcotest.test_case "one char deltas produce updates" `Quick
            test_one_char_deltas_produce_updates;
          Alcotest.test_case "delta wrong session" `Quick
            test_delta_wrong_session;
          Alcotest.test_case "delta out of order seq" `Quick
            test_delta_out_of_order_seq;
        ] );
      ( "generation",
        [
          Alcotest.test_case "generation completed" `Quick
            test_generation_completed;
          Alcotest.test_case "generation failed" `Quick test_generation_failed;
          Alcotest.test_case "generation wrong id" `Quick
            test_generation_wrong_id;
        ] );
    ]
