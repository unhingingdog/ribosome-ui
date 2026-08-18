type state = {
  processor: Telomere.Processor.processor_state;
  committed: Ribosome_core.Types.template option;
}

type update =
  | Pending
  | Updated of Ribosome_core.Types.template
  | Rejected of string
  | Corrupted

let create committed = {
  processor = Telomere.Processor.create_processor ();
  committed;
}

let reconcile committed candidate =
  match committed with
  | None -> Ok candidate
  | Some current ->
    (match Ribosome_core.Reconciler.reconcile current candidate with
     | Ribosome_core.Reconciler.Found reconciled -> Ok reconciled
     | Ribosome_core.Reconciler.NotFound _ -> Error "template patch has no matching id")

let feed state delta =
  let output, processor = Telomere.Processor.feed state.processor delta in
  let next = { state with processor } in
  match output with
  | Telomere.Processor.Pending -> Pending, next
  | Telomere.Processor.Corrupted -> Corrupted, next
  | Telomere.Processor.Completion suffix ->
    let candidate = processor.buffer ^ suffix in
    (match Ribosome_native_codec.TemplateCodec.decode_string_template candidate with
     | Error error -> Rejected error, next
     | Ok decoded ->
       match reconcile state.committed decoded with
       | Error error -> Rejected error, next
       | Ok committed -> Updated committed, { next with committed = Some committed })
