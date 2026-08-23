(* UI WebSocket handler.

   Thin codec around Ui_runtime. Authenticates on attach using the UI nonce.
   Sends the current snapshot immediately after attachment. Closes malformed
   or unauthenticated sockets with policy-error codes. *)

let max_message_size = 1 lsl 20 (* 1 MiB *)

let handle_websocket ~runtime websocket =
  let open Lwt.Syntax in
  Debug.log "ui_ws" "connection opened";
  let rec loop () =
    let* msg = Dream.receive websocket in
    match msg with
    | None -> begin
      Debug.log "ui_ws" "connection closed (EOF)";
      Lwt.return_unit
    end
    | Some data when String.length data > max_message_size ->
        Debug.log "ui_ws" (Printf.sprintf "closing: message too large (%d bytes)" (String.length data));
        let* () = Dream.close_websocket websocket in
        Lwt.return_unit
    | Some data -> (
        match Yojson.Safe.from_string data with
        | json -> (
            match Ui_protocol.decode_message json with
            | Ok ui_msg -> (
                Debug.log "ui_ws" (Printf.sprintf "decoded msg len=%d" (String.length data));
                match Ui_runtime.handle_message runtime ui_msg with
                | Ok _ -> loop ()
                | Error e ->
                    Debug.log "ui_ws" (Printf.sprintf "runtime error, closing: %s" (Ui_runtime.error_string e));
                    let* () = Dream.close_websocket websocket in
                    Lwt.return_unit)
            | Error e ->
                Debug.log "ui_ws" (Printf.sprintf "decode error, closing: %s" e);
                let* () = Dream.close_websocket websocket in
                Lwt.return_unit)
        | exception Yojson.Json_error msg ->
            Debug.log "ui_ws" (Printf.sprintf "json parse error, closing: %s" msg);
            let* () = Dream.close_websocket websocket in
            Lwt.return_unit)
  in
  loop ()

let handler ~runtime _request = Dream.websocket (handle_websocket ~runtime)
