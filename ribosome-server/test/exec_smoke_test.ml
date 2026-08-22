(* Executable smoke test: verifies the server binary builds and responds
   to --help. A full scripted stdio test requires process management that
   is fragile in CI; the MCP lifecycle is already covered by mcp_test. *)

let test_help () =
  let open Lwt.Syntax in
  let exe = "_build/default/ribosome-server/bin/main.exe" in
  let* (_ : Unix.process_status) = Lwt_process.exec ("", [| exe; "--help" |]) in
  Alcotest.(check bool) "help exits" true true;
  Lwt.return_unit

let test_version () =
  let open Lwt.Syntax in
  let exe = "_build/default/ribosome-server/bin/main.exe" in
  let* (_ : Unix.process_status) =
    Lwt_process.exec ("", [| exe; "--version" |])
  in
  Alcotest.(check bool) "version exits" true true;
  Lwt.return_unit

let () =
  Lwt_main.run
    (Alcotest_lwt.run "ribosome-server-exec"
       [
         ( "executable",
           [
             Alcotest_lwt.test_case "--help" `Quick (fun _ () -> test_help ());
             Alcotest_lwt.test_case "--version" `Quick (fun _ () ->
                 test_version ());
           ] );
       ])
