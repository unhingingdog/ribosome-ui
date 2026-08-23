open Ribosome_server_lib

(* Test helpers shared between vertical-slice tests.
   Builds a runtime with a pre-populated session and tree. *)

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

let template_json =
  {json|{"kind":"submittable","id":"form1","value":[{"kind":"input","id":"inp1","value":"hi"}],"button":{"id":"btn1","label":"Go","action":"Submit"}}|json}

(* Create a registry + session with a completed tree at revision 1 *)
let make_runtime_with_tree () =
  let registry = Session_registry.create () in
  let _ =
    Session_registry.start ~id_gen:(make_id_gen ()) ~registry
      ~harness_session_id:"hs-1" ~harness_nonce:"hn-1" ()
  in
  let inbox = Ui_client.create_inbox () in
  let broadcast = Ui_client.make_inbox_broadcast inbox in
  let runtime = Ui_runtime.create ~registry ~broadcast in
  Ui_runtime.register_session runtime ~session_id:"rs-1";
  let session = Ribosome.Session.create ~id:"rs-1" ~mode:Ribosome.Mode.ui in
  let session =
    match Ribosome.Session.start_generation session ~gen_id:"gen-1" with
    | Ok s -> s
    | Error e -> failwith e
  in
  let session =
    match
      Ribosome.Session.feed_delta session ~gen_id:"gen-1" ~seq:0
        ~delta:template_json
    with
    | Ok (s, _) -> s
    | Error e -> failwith e
  in
  let session =
    match Ribosome.Session.complete_generation session ~gen_id:"gen-1" with
    | Ok s -> s
    | Error e -> failwith e
  in
  Ui_runtime.put_session runtime ~session_id:"rs-1" session;
  (registry, runtime, inbox)
