open Balancer

type processor_state = { balancer : balancer_state; buffer : string }
type output = Pending | Completion of string | Corrupted

let create_processor () = { balancer = create (); buffer = "" }

let feed (ps : processor_state) (chunk : string) : output * processor_state =
  let new_buffer = ps.buffer ^ chunk in
  Debug.log "processor"
    (Printf.sprintf "feed chunk_len=%d buffer_len=%d" (String.length chunk)
       (String.length new_buffer));
  match process_delta ps.balancer chunk with
  | Ok (completion, new_balancer) ->
      Debug.log "processor"
        (Printf.sprintf "completion suffix_len=%d" (String.length completion));
      let new_ps = { balancer = new_balancer; buffer = new_buffer } in
      (Completion completion, new_ps)
  | Error (NotClosable, new_balancer) ->
      Debug.log "processor" "pending (not closable)";
      let new_ps = { balancer = new_balancer; buffer = new_buffer } in
      (Pending, new_ps)
  | Error (_, new_balancer) ->
      Debug.log "processor" "corrupted";
      let new_ps = { balancer = new_balancer; buffer = new_buffer } in
      (Corrupted, new_ps)
