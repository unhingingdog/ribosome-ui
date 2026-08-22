(* Shared helpers for readable Ribosome test assertions.

   The template ADT and codecs land in Feature 3. For now this module keeps
   a single helper used by the smoke test to assert the package wires up
   against [telomere]. *)

let processor_roundtrips () : bool =
  let state = Telomere.Processor.create_processor () in
  let output, _ = Telomere.Processor.feed state "{}" in
  match output with Telomere.Processor.Completion _ -> true | _ -> false
