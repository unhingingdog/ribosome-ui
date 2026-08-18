type request = {
  thread: Thread.thread;
  skill: Skills.skill;
  semantic_input: string;
  tree: Ribosome_core.Types.template option;
}

type turn = {
  id: string;
}

type phase =
  | Idle
  | Waiting of Codex_protocol.JsonRpc.request_id
  | Active of turn

type error =
  | Already_active
  | Unexpected_event
  | Server_error of Codex_protocol.JsonRpc.error
  | Invalid_response of string

type outcome =
  | Requested of Client.command
  | Turn_started of turn

let ( let* ) = Result.bind

let prompt semantic_input tree =
  let tree_context = match tree with
    | None -> "There is no existing UI. Generate the initial Ribosome tree."
    | Some tree ->
      "The authoritative current Ribosome tree is:\n"
      ^ Melange_json.to_string (Ribosome_native_codec.TemplateCodec.encode_template tree)
  in
  String.concat "\n\n" [
    "Use the ribosome skill. Emit only the requested Ribosome JSON.";
    tree_context;
    "Semantic UI input:\n" ^ semantic_input;
  ]

let params request =
  `Assoc [
    ("threadId", `String request.thread.id);
    ("input", `List [
      `Assoc [
        ("type", `String "skill");
        ("name", `String request.skill.name);
        ("path", `String request.skill.path);
      ];
      `Assoc [
        ("type", `String "text");
        ("text", `String (prompt request.semantic_input request.tree));
        ("text_elements", `List []);
      ];
    ]);
    ("approvalPolicy", `String "never");
    ("sandboxPolicy", `String "read-only");
  ]

let start phase client request =
  match phase with
  | Idle ->
    let pending, command, client = Client.request client "turn/start" (Some (params request)) in
    Ok (Requested command, client, Waiting pending.id)
  | Waiting _ | Active _ -> Error Already_active

let decode_turn = function
  | `Assoc fields ->
    (match Stdlib.List.assoc_opt "turn" fields with
     | Some (`Assoc turn_fields) ->
       (match Stdlib.List.assoc_opt "id" turn_fields with
        | Some (`String id) -> Ok { id }
        | Some _ -> Error (Invalid_response "expected string: turn.id")
        | None -> Error (Invalid_response "missing field: turn.id"))
     | Some _ -> Error (Invalid_response "expected object: turn")
     | None -> Error (Invalid_response "missing field: turn"))
  | _ -> Error (Invalid_response "expected turn response object")

let receive phase client event =
  match phase, event with
  | Waiting id, Client.Response { request; result = Ok result }
    when request.id = id && request.method_ = "turn/start" ->
    let* turn = decode_turn result in
    Ok (Turn_started turn, client, Active turn)
  | Waiting id, Client.Response { request; result = Error error }
    when request.id = id && request.method_ = "turn/start" -> Error (Server_error error)
  | Idle, _ | Waiting _, _ | Active _, _ -> Error Unexpected_event
