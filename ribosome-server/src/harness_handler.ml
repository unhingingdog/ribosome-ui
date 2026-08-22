(* Harness WebSocket handler.

   Thin codec around Harness_runtime. Authenticates on attach using the
   nonce injected at kickoff. Closes malformed or unauthenticated sockets
   with policy-error codes. Removes connections on termination. *)

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
            match Harness_protocol.decode_message json with
            | Ok harness_msg -> (
                match Harness_runtime.handle_message runtime harness_msg with
                | Ok _ -> loop ()
                | Error _ ->
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
            | Error _ ->
                let* () = Dream.close_websocket websocket in
                Lwt.return_unit)
        | exception Yojson.Json_error _ ->
            let* () = Dream.close_websocket websocket in
            Lwt.return_unit)
  in
  loop ()

let handler ~runtime _request = Dream.websocket (handle_websocket ~runtime)
