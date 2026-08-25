(* Harness WebSocket handler.

   Thin codec around Harness_runtime. Registers the WebSocket in the
   connection table on attach so broadcast callbacks (user_turn) can send
   directly via Lwt.async. Unregisters on close.

   Includes a generation idle timeout: if no deltas arrive for 15 seconds
   while a generation is active, the generation is auto-completed. This
   handles silent WebSocket drops where generation_completed is lost. *)

let max_message_size = 1 lsl 20 (* 1 MiB *)
let generation_idle_timeout = 15.0 (* seconds *)

let handle_websocket ~runtime ~conns websocket =
  let open Lwt.Syntax in
  Debug.log "harness_ws" "connection opened";
  Connection_table.set_pending conns websocket;
  let session_id = ref None in
  let idle_timer = ref None in

  let cancel_idle_timer () =
    match !idle_timer with
    | Some t -> Lwt.cancel t; idle_timer := None
    | None -> ()
  in

  let start_idle_timer sid =
    cancel_idle_timer ();
    let task =
      Lwt.bind (Lwt_unix.sleep generation_idle_timeout) (fun () ->
        let session = Harness_runtime.get_session runtime ~session_id:sid in
        (match session with
         | Some s when s.Ribosome.Session.generation <> None ->
             let gen_id =
               match s.Ribosome.Session.generation with
               | Some g -> g.Ribosome.Session.id
               | None -> ""
             in
             Debug.log "harness_ws"
               (Printf.sprintf "generation idle timeout, auto-completing gen=%s session=%s"
                  gen_id sid);
             ignore (Harness_runtime.handle_generation_completed runtime
                       ~session_id:sid ~generation_id:gen_id)
         | _ -> ());
        Lwt.return_unit)
    in
    Lwt.async (fun () -> task);
    idle_timer := Some task
  in

  let rec loop () =
    let* msg = Dream.receive websocket in
    match msg with
    | None -> begin
        cancel_idle_timer ();
        Connection_table.clear_pending conns;
        (match !session_id with
        | Some sid -> Connection_table.unregister conns ~session_id:sid
        | None -> ());
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
                (match harness_msg with
                 | Harness_protocol.Attach a ->
                     Connection_table.clear_pending conns;
                     session_id := Some a.session_id;
                     Connection_table.register conns ~session_id:a.session_id
                       websocket
                  | Harness_protocol.Delta _ ->
                     (match !session_id with
                      | Some sid -> start_idle_timer sid
                      | None -> ())
                 | Harness_protocol.GenerationCompleted _ ->
                     cancel_idle_timer ()
                 | Harness_protocol.GenerationFailed _ ->
                     cancel_idle_timer ()
                 | _ -> ());
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

let handler ~runtime ~conns _request =
  Dream.websocket (handle_websocket ~runtime ~conns)
