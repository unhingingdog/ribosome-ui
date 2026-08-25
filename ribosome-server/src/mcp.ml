(* Minimal MCP lifecycle handler.

   Implements the MCP 2025-11-25 subset: initialize, notifications/initialized,
   ping, tools/list, and the start tool. Operational requests are rejected
   before initialization completes. *)

let protocol_version = "2025-11-25"

type config = {
  registry : Session_registry.t;
  id_gen : Session_registry.id_gen;
  skill_loader : string -> string option;
}

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

let ( let* ) = Result.bind
let raw_json_suffix = "\n\nYour next response must be raw template JSON only."

let handle_start (config : config) (params : Yojson.Safe.t option) :
    (Yojson.Safe.t, string) result =
  Debug.log "mcp" "tools/call start";
  let* params =
    match params with
    | Some (`Assoc _) as p -> Ok p
    | Some _ -> Error "params must be an object"
    | None -> Error "missing params"
  in
  let assoc = match params with Some (`Assoc a) -> a | _ -> [] in
  let arguments =
    match Stdlib.List.assoc_opt "arguments" assoc with
    | Some (`Assoc a) -> a
    | _ -> []
  in
  let mode =
    match Stdlib.List.assoc_opt "mode" arguments with
    | Some (`String m) -> m
    | _ -> "ui"
  in
  let* harness_session_id =
    match Stdlib.List.assoc_opt "_harness_session_id" arguments with
    | Some (`String s) -> Ok s
    | _ -> Error "missing _harness_session_id"
  in
  let* harness_nonce =
    match Stdlib.List.assoc_opt "_nonce" arguments with
    | Some (`String s) -> Ok s
    | _ -> Error "missing _nonce"
  in
  let* mode_entry =
    match Ribosome.Mode_registry.for_id mode with
    | Some m -> Ok m
    | None -> Error ("unknown mode: " ^ mode)
  in
  let skill_paths = mode_entry.Ribosome.Mode.skills in
  let skill_body =
    Stdlib.List.filter_map config.skill_loader skill_paths
    |> String.concat "\n\n---\n\n"
  in
  let result =
    match
      Session_registry.start ~mode ~id_gen:config.id_gen ~registry:config.registry
        ~harness_session_id ~harness_nonce ()
    with
    | Error `Duplicate ->
        (match Session_registry.find config.registry harness_session_id with
         | Some entry -> Ok entry
         | None -> Error "duplicate harness session but not found")
    | Ok entry -> Ok entry
  in
  match result with
  | Error msg -> Error msg
  | Ok entry ->
      Debug.log "mcp"
        (Printf.sprintf "start OK session_id=%s mode=%s"
           entry.Session_registry.session_id entry.Session_registry.mode);
      let content =
        `List
          [
            `Assoc
              [
                ("type", `String "text");
                ("text", `String (skill_body ^ raw_json_suffix));
              ];
          ]
      in
      let structured =
        `Assoc
          [
            ("session_id", `String entry.Session_registry.session_id);
            ("ui_nonce", `String entry.Session_registry.ui_nonce);
            ("mode", `String entry.Session_registry.mode);
          ]
      in
      Ok (`Assoc [ ("content", content); ("structuredContent", structured) ])

let handle (config : config) (state : state) (msg : Jsonrpc.message) :
    state * Jsonrpc.message option =
  let method_ =
    match msg with
    | Jsonrpc.Request r -> r.method_
    | Jsonrpc.Notification n -> n.method_
    | _ -> "<response>"
  in
  Debug.log "mcp"
    (Printf.sprintf "handle state=%s method=%s"
       (match state with Uninitialized -> "uninit" | Initialized -> "init")
       method_);
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
      | Jsonrpc.Request r when r.method_ = "tools/call" -> (
          let tool_name =
            match r.params with
            | Some (`Assoc a) -> (
                match Stdlib.List.assoc_opt "name" a with
                | Some (`String n) -> Some n
                | _ -> None)
            | _ -> None
          in
          match tool_name with
          | Some "start" -> (
              match handle_start config r.params with
              | Ok result ->
                  (Initialized, Some (Jsonrpc.make_success_response r.id result))
              | Error msg ->
                  ( Initialized,
                    Some
                      (Jsonrpc.make_error_response r.id Jsonrpc.Invalid_params
                         msg) ))
          | Some name ->
              ( Initialized,
                Some
                  (Jsonrpc.make_error_response r.id Jsonrpc.Method_not_found
                     ("unknown tool: " ^ name)) )
          | None ->
              ( Initialized,
                Some
                  (Jsonrpc.make_error_response r.id Jsonrpc.Invalid_params
                     "missing tool name") ))
      | Jsonrpc.Request r ->
          let resp =
            Jsonrpc.make_error_response r.id Jsonrpc.Method_not_found
              ("method not found: " ^ r.method_)
          in
          (Initialized, Some resp)
      | Jsonrpc.Notification _ -> (Initialized, None)
      | Jsonrpc.Success _ | Jsonrpc.Error_response _ -> (Initialized, None))
