(* MCP stdio processing loop.

   Reads newline-delimited JSON-RPC messages from stdin, passes them through
   the MCP handler, and writes responses to stdout. All logs go to stderr.
   Handles EOF and termination without emitting invalid MCP output. *)

let read_lines ic f =
  let open Lwt.Syntax in
  let rec loop () =
    let* line =
      try Lwt.return (Some (input_line ic))
      with End_of_file -> Lwt.return_none
    in
    match line with
    | None -> Lwt.return_unit
    | Some line when String.trim line = "" -> loop ()
    | Some line ->
        let trimmed = String.trim line in
        f trimmed;
        loop ()
  in
  loop ()

let process_stdin ~config =
  let state = ref Mcp.Uninitialized in
  let oc = stdout in
  Debug.log "stdio" "starting stdin loop";
  read_lines stdin (fun line ->
      match Jsonrpc.decode_line line with
      | Error e ->
          Debug.log "stdio" (Printf.sprintf "decode error: %s" e);
          let err =
            Jsonrpc.encode_to_line
              (Jsonrpc.make_error_response (Int_id 0) Jsonrpc.Parse_error e)
          in
          output_string oc err;
          flush oc
      | Ok msg -> (
          let new_state, resp = Mcp.handle config !state msg in
          state := new_state;
          match resp with
          | Some resp_msg ->
              output_string oc (Jsonrpc.encode_to_line resp_msg);
              flush oc
          | None -> ()))
