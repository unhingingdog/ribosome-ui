open EngineTypes

type t = {
  config: config;
  renderer: (React.element -> unit) option;
  mutable state: State.any_state;
  mutable history: chat_message list;
  mutable processor: Telomere.Processor.processor_state;
  mutable last_template: Types.template option;
  mutable last_error: string option;
}

let create_runtime config = {
  config;
  renderer = EngineFrontendReact.create_renderer config.root;
  state = State.AnyState State.Idle;
  history = [];
  processor = EngineBackend.initial_processor_state;
  last_template = None;
  last_error = None;
}

let set_error t details =
  Utils.Log.debug "[ribosome engine] set_error" details;
  t.last_error <- Some details;
  (* TODO: Wire engine retry behavior into the existing State.retry mechanism. *)
  t.state <- State.fail t.state details;
  t.config.callbacks.on_error details

let reset_turn t =
  t.processor <- EngineBackend.initial_processor_state;
  t.last_template <- None;
  t.last_error <- None

let rec render_template t template =
  Utils.Log.debug1 "[ribosome engine] render_template";
  match t.renderer with
  | None -> ()
  | Some render ->
    EngineFrontendReact.render_template_with_submit
      template
      t.config.components
      (fun payload -> submit t payload)
    |> render

and on_delta t delta =
  Utils.Log.debug "[ribosome engine] on_delta" delta;
  match State.receive_chunk t.state ~chunk:delta with
  | Error message ->
    set_error t message
  | Ok state ->
    t.state <- state;
    (match EngineBackend.handle_chunk delta t.processor with
    | EngineBackend.Telomere_result.Pending processor ->
      Utils.Log.debug1 "[ribosome engine] backend pending";
      t.processor <- processor
    | EngineBackend.Telomere_result.Parsed (template, processor) ->
      Utils.Log.debug1 "[ribosome engine] backend parsed, rendering";
      t.processor <- processor;
      t.last_template <- Some template;
      render_template t template
    | EngineBackend.Telomere_result.Failed (message, processor) ->
      Utils.Log.debug "[ribosome engine] backend failed" message;
      t.processor <- processor;
      set_error t message)

and on_chunk t payload =
  Utils.Log.debug "[ribosome engine] raw stream payload" payload;
  match t.config.stream_adapter payload with
  | Error message ->
    set_error t message
  | Ok None -> ()
  | Ok (Some delta) ->
    if delta <> "" then begin
      Utils.Log.debug "[ribosome engine] extracted delta" delta;
      on_delta t delta
    end

and on_done t = function
  | Http.Failed _ -> ()
  | Http.Complete ->
    Utils.Log.debug1 "[ribosome engine] stream complete";
    (match t.last_error with
    | Some _ -> ()
    | None ->
      match State.complete t.state with
      | Error message ->
        set_error t message
      | Ok state ->
        t.state <- state;
        (match t.last_template with
        | None -> ()
        | Some _ ->
          (* TODO: Consider processing or compacting assistant history for prompt quality. *)
          t.history <- t.history @ [{ role = Bot; content = t.processor.buffer }]);
        t.config.callbacks.on_message_complete t.last_template)

and run_turn t ~user_message ~interaction_goal =
  reset_turn t;
  Utils.Log.debug "[ribosome engine] run_turn user_message" user_message;
  t.history <- t.history @ [{ role = User; content = user_message }];
  let context = {
    system_prompt =
      Prompt.create_llm_prompt
        t.config.templates
        t.config.assets
        t.config.goal_prompt
        interaction_goal;
    messages = t.history;
  } in
  let request = t.config.request context in
  Utils.Log.debug "[ribosome engine] request url" request.url;
  Utils.Log.debug "[ribosome engine] request body" request.body;
  Http.post
    ~url:request.url
    ~headers:request.headers
    ~body:request.body
    ~on_chunk:(on_chunk t)
    ~on_done:(on_done t)
    ~on_error:(set_error t)

and kick_off t =
  Utils.Log.debug1 "[ribosome engine] kick_off";
  let prompt =
    Prompt.create_llm_prompt
      t.config.templates
      t.config.assets
      t.config.goal_prompt
      None
  in
  match State.kick_off t.state ~prompt with
  | Error message ->
    set_error t message
  | Ok state ->
    t.state <- state;
    run_turn t ~user_message:t.config.goal_prompt ~interaction_goal:None

and submit t payload =
  Utils.Log.debug1 "[ribosome engine] submit";
  t.config.callbacks.on_submit payload;
  let interaction_goal =
    payload
    |> SubmitTypes.submission_payload_to_json
    |> Melange_json.to_string
  in
  let prompt =
    Prompt.create_llm_prompt
      t.config.templates
      t.config.assets
      t.config.goal_prompt
      (Some interaction_goal)
  in
  match State.kick_off t.state ~prompt with
  | Error message ->
    set_error t message
  | Ok state ->
    t.state <- state;
    run_turn
      t
      ~user_message:interaction_goal
      ~interaction_goal:(Some interaction_goal)

let reset t =
  t.state <- State.AnyState State.Idle;
  t.history <- [];
  reset_turn t

let create config =
  let t = create_runtime config in
  kick_off t;
  {
    reset = (fun () -> reset t);
    history = (fun () -> t.history);
  }
