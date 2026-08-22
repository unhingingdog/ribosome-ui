(* Minimal MCP lifecycle handler.

   Implements the MCP 2025-11-25 subset: initialize, notifications/initialized,
   ping, and tools/list. Operational requests are rejected before
   initialization completes. *)

let protocol_version = "2025-11-25"

type state = Uninitialized | Initialized

let server_info : Yojson.Safe.t =
  `Assoc [ ("name", `String "ribosome"); ("version", `String Ribosome.version) ]

let capabilities : Yojson.Safe.t = `Assoc [ ("tools", `Assoc []) ]

let instructions : string =
  "Ribosome is a generative-UI runtime. Call the `start` tool to begin a UI \
   session. After start, the next assistant response must be raw template JSON \
   only — no markdown, no explanations, no code fences."

let tools : Yojson.Safe.t =
  `List
    [
      `Assoc
        [
          ("name", `String "start");
          ("description", `String "Start a Ribosome UI session");
          ( "inputSchema",
            `Assoc
              [
                ("type", `String "object");
                ( "properties",
                  `Assoc
                    [
                      ( "mode",
                        `Assoc
                          [
                            ("type", `String "string");
                            ("default", `String "ui");
                            ("description", `String "The UI mode to use");
                          ] );
                    ] );
                ("required", `List []);
              ] );
        ];
    ]

let initialize_result : Yojson.Safe.t =
  `Assoc
    [
      ("protocolVersion", `String protocol_version);
      ("capabilities", capabilities);
      ("serverInfo", server_info);
      ("instructions", `String instructions);
    ]

let handle (state : state) (msg : Jsonrpc.message) :
    state * Jsonrpc.message option =
  match state with
  | Uninitialized -> (
      match msg with
      | Jsonrpc.Request r when r.method_ = "initialize" ->
          let resp = Jsonrpc.make_success_response r.id initialize_result in
          (Uninitialized, Some resp)
      | Jsonrpc.Request r ->
          let resp =
            Jsonrpc.make_error_response r.id Jsonrpc.Invalid_request
              "server not initialized"
          in
          (Uninitialized, Some resp)
      | Jsonrpc.Notification n when n.method_ = "notifications/initialized" ->
          (Initialized, None)
      | Jsonrpc.Notification _ -> (Uninitialized, None)
      | Jsonrpc.Success _ | Jsonrpc.Error_response _ -> (Uninitialized, None))
  | Initialized -> (
      match msg with
      | Jsonrpc.Request r when r.method_ = "initialize" ->
          let resp =
            Jsonrpc.make_error_response r.id Jsonrpc.Invalid_request
              "already initialized"
          in
          (Initialized, Some resp)
      | Jsonrpc.Request r when r.method_ = "ping" ->
          let resp = Jsonrpc.make_success_response r.id `Null in
          (Initialized, Some resp)
      | Jsonrpc.Request r when r.method_ = "tools/list" ->
          let resp =
            Jsonrpc.make_success_response r.id (`Assoc [ ("tools", tools) ])
          in
          (Initialized, Some resp)
      | Jsonrpc.Request r ->
          let resp =
            Jsonrpc.make_error_response r.id Jsonrpc.Method_not_found
              ("method not found: " ^ r.method_)
          in
          (Initialized, Some resp)
      | Jsonrpc.Notification _ -> (Initialized, None)
      | Jsonrpc.Success _ | Jsonrpc.Error_response _ -> (Initialized, None))
