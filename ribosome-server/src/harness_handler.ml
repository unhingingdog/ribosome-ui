(* Harness WebSocket handler.

   Thin codec around Harness_runtime. Authenticates on attach using the
   nonce injected at kickoff. Closes malformed or unauthenticated sockets
   with policy-error codes. Removes connections on termination. *)

let max_message_size = 1 lsl 20 (* 1 MiB *)

let handle_websocket ~runtime websocket =
  let open Lwt.Syntax in
  Debug.log "harness_ws" "connection opened";
  let rec loop () =
    let* msg = Dream.receive websocket in
    match msg with
    | None -> begin
        Debug.log "harness_ws" "connection closed (EOF)";
        Lwt.return_unit
      end
    | Some data when String.length data > max_message_size ->
        Debug.log "harness_ws"
          (Printf.sprintf "closing: message too large (%d bytes)"
             (String.length data));
        let* () = Dream.close_websocket websocket in
        Lwt.return_unit
    | Some data -> (
        match Yojson.Safe.from_string data with
        | json -> (
            match Harness_protocol.decode_message json with
            | Ok harness_msg -> (
                Debug.log "harness_ws"
                  (Printf.sprintf "decoded msg len=%d" (String.length data));
                match Harness_runtime.handle_message runtime harness_msg with
                | Ok _ -> loop ()
                | Error _ ->
                    Debug.log "harness_ws"
                      "runtime rejection sent, keeping socket open";
                    let rejection_json =
                      `Assoc
                        [
                          ("kind", `String "rejection");
                          ("session_id", `String "");
                          ("reason", `String "rejected");
                        ]
                    in
                    let* () =
                      Dream.send websocket
                        (Yojson.Safe.to_string rejection_json)
                    in
                    loop ())
            | Error e ->
                Debug.log "harness_ws"
                  (Printf.sprintf "decode error, closing: %s" e);
                let* () = Dream.close_websocket websocket in
                Lwt.return_unit)
        | exception Yojson.Json_error msg ->
            Debug.log "harness_ws"
              (Printf.sprintf "json parse error, closing: %s" msg);
            let* () = Dream.close_websocket websocket in
            Lwt.return_unit)
  in
  loop ()

let handler ~runtime _request = Dream.websocket (handle_websocket ~runtime)
