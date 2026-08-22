(* UI WebSocket handler.

   Thin codec around Ui_runtime. Authenticates on attach using the UI nonce.
   Sends the current snapshot immediately after attachment. Closes malformed
   or unauthenticated sockets with policy-error codes. *)

let max_message_size = 1 lsl 20 (* 1 MiB *)

let handle_websocket ~runtime websocket =
  let open Lwt.Syntax in
  let rec loop () =
    let* msg = Dream.receive websocket in
    match msg with
    | None -> Lwt.return_unit
    | Some data when String.length data > max_message_size ->
        let* () = Dream.close_websocket websocket in
        Lwt.return_unit
    | Some data -> (
        match Yojson.Safe.from_string data with
        | json -> (
            match Ui_protocol.decode_message json with
            | Ok ui_msg -> (
                match Ui_runtime.handle_message runtime ui_msg with
                | Ok _ -> loop ()
                | Error _ ->
                    let* () = Dream.close_websocket websocket in
                    Lwt.return_unit)
            | Error _ ->
                let* () = Dream.close_websocket websocket in
                Lwt.return_unit)
        | exception Yojson.Json_error _ ->
            let* () = Dream.close_websocket websocket in
            Lwt.return_unit)
  in
  loop ()

let handler ~runtime _request = Dream.websocket (handle_websocket ~runtime)
