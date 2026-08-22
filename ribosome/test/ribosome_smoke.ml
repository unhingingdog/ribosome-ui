(* Smoke test: proves Dune discovers the Ribosome suite and that the
   package links correctly against [telomere]. Template codec and
   reconciliation tests land in Features 3 and 4. *)

let test_version_is_string () =
  Alcotest.(check string) "version is a string" "0.0.0" Ribosome.version

let test_processor_wires_up () =
  let ok = Test_support.processor_roundtrips () in
  Alcotest.(check bool) "telomere processor wired through ribosome" true ok

let () =
  Alcotest.run "ribosome-smoke"
    [
      ( "smoke",
        [
          Alcotest.test_case "version is string" `Quick test_version_is_string;
          Alcotest.test_case "processor wires up" `Quick test_processor_wires_up;
        ] );
    ]
