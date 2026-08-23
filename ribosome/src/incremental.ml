type update = Updated of Template.t | Pending | Rejected of string | Corrupted

type state = {
  processor : Telomere.Processor.processor_state;
  buffer : string;
  committed : Template.t option;
}

let create ?committed () =
  { processor = Telomere.Processor.create_processor (); buffer = ""; committed }

let decode_candidate buffer suffix =
  let json_str = buffer ^ suffix in
  match Template.decode_string json_str with
  | Ok tree -> (
      match Template_validate.validate tree with
      | [] -> Ok tree
      | errors ->
          Error
            ("validation failed: "
            ^ String.concat "; "
                (Stdlib.List.map
                   (fun (e : Template_validate.error) -> e.message)
                   errors)))
  | Error e -> Error (Codec_error.to_string e)

let feed state delta =
  let new_buffer = state.buffer ^ delta in
  Debug.log "incremental" (Printf.sprintf "feed delta_len=%d buffer_len=%d" (String.length delta) (String.length new_buffer));
  let output, new_processor = Telomere.Processor.feed state.processor delta in
  match output with
  | Telomere.Processor.Corrupted ->
      Debug.log "incremental" "corrupted";
      ({ state with processor = new_processor; buffer = new_buffer }, Corrupted)
  | Telomere.Processor.Pending ->
      ({ state with processor = new_processor; buffer = new_buffer }, Pending)
  | Telomere.Processor.Completion suffix -> (
      Debug.log "incremental" (Printf.sprintf "completion suffix_len=%d" (String.length suffix));
      match decode_candidate new_buffer suffix with
      | Ok candidate -> (
          Debug.log "incremental" (Printf.sprintf "decoded id=%s" (Template.id candidate));
          match state.committed with
          | Some committed -> (
              match
                Template_reconcile.patch ~target_id:(Template.id candidate)
                  ~replacement:candidate committed
              with
              | Ok reconciled ->
                  if reconciled = committed then begin
                    Debug.log "incremental" "reconcile no-op (unchanged)";
                    ( {
                        state with
                        processor = new_processor;
                        buffer = new_buffer;
                      },
                      Pending )
                  end else begin
                    Debug.log "incremental" "reconcile updated";
                    ( {
                        processor = new_processor;
                        buffer = new_buffer;
                        committed = Some reconciled;
                      },
                      Updated reconciled )
                  end
              | Error e ->
                  Debug.log "incremental" (Printf.sprintf "reconcile rejected: %s" e);
                  ( { state with processor = new_processor; buffer = new_buffer },
                    Rejected e ))
          | None ->
              Debug.log "incremental" "first commit";
              ( {
                  processor = new_processor;
                  buffer = new_buffer;
                  committed = Some candidate;
                },
                Updated candidate ))
      | Error e ->
          Debug.log "incremental" (Printf.sprintf "decode rejected: %s" e);
          ( { state with processor = new_processor; buffer = new_buffer },
            Rejected e ))
