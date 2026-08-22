(* Smoke test: proves Dune discovers the ribosome-server suite and that
   Alcotest-Lwt wires up against the private server library. MCP, harness
   and UI protocol tests land in Feature 5. *)

let test_core_version_is_set () =
  Alcotest.(check bool)
    "core_version is non-empty" true
    (Test_support.core_version_is_set ())

(* A trivial Lwt test proving the async runner links. *)
let test_lwt_resolves () =
  let open Lwt.Syntax in
  let* () = Lwt.return_unit in
  Alcotest.(check bool) "lwt promise resolves" true true;
  Lwt.return_unit

let () =
  Lwt_main.run
    (Alcotest_lwt.run "ribosome-server-smoke"
       [
         ( "smoke",
           [
             Alcotest_lwt.test_case "core version is set" `Quick
               (fun _switch () -> Lwt.return (test_core_version_is_set ()));
             Alcotest_lwt.test_case "lwt resolves" `Quick (fun _switch () ->
                 test_lwt_resolves ());
           ] );
       ])
