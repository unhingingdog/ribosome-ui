(lang dune 3.18)
(generate_opam_files)

(package
 (name telomere)
 (synopsis "Incremental JSON completion for streamed LLM output")
 (description
  "Telomere receives streamed text and answers whether it can be closed into valid JSON now, returning the suffix required to close it. It is the mandatory incremental parsing layer in the Ribosome streaming pipeline.")
 (depends
  (ocaml (>= 5.2))
  (alcotest (and :with-test (>= 1.8.0)))
  (qcheck-core (and :with-test (>= 0.22)))
  (qcheck-alcotest (and :with-test (>= 0.22)))
  (yojson (and :with-test))))

(package
 (name ribosome)
 (synopsis "Typed template ADT, codec, validation, and reconciliation for generative UI")
 (description
  "Ribosome owns a closed OCaml template ADT plus JSON codecs, invariant validation, stable-ID reconciliation, session state, and mode/skill bundles. It has no dependency on MCP, Dream, WebSockets, or any harness.")
 (depends
  (ocaml (>= 5.2))
  telomere
  yojson
  (alcotest (and :with-test (>= 1.8.0)))))

(package
 (name ribosome-server)
 (synopsis "MCP control, harness stream, and WebSocket UI transport for Ribosome")
 (description
  "ribosome-server implements a minimal MCP subset over stdio, the harness streaming protocol, and Dream WebSocket UI transport. It bridges agent harnesses to the Ribosome core pipeline.")
 (depends
  (ocaml (>= 5.2))
  ribosome
  yojson
  lwt
  dream
  cmdliner
  (alcotest (and :with-test (>= 1.8.0)))
  (alcotest-lwt (and :with-test (>= 1.8.0)))))

;; No legacy Melange/React packages — removed in Feature 8.
