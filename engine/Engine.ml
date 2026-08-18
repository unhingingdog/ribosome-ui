open EngineTypes

let root_template =
  Types.Container {
    kind = "container";
    id = "root";
    direction = Templates.Container.Vertical;
    children = [];
  }

type t = {
  config: config;
  renderer: (React.element -> unit) option;
  mutable state: State.any_state;
  mutable history: chat_message list;
  mutable processor: Telomere.Processor.processor_state;
  mutable last_template: Types.template option;
  mutable last_error: string option;
  mutable abort: (unit -> unit) option;
}

let create_runtime config = {
  config;
  renderer = EngineFrontendReact.create_renderer config.root;
  state = State.AnyState State.Idle;
  history = [];
  processor = EngineBackend.initial_processor_state;
  last_template = Some root_template;
  last_error = None;
  abort = None;
}

let abort_in_flight t =
  match t.abort with
  | Some abort ->
    Utils.Log.debug1 "[ribosome engine] aborting in-flight request";
    abort ();
    t.abort <- None
  | None -> ()

let set_error t details =
  Utils.Log.debug "[ribosome engine] set_error" details;
  t.abort <- None;
  t.last_error <- Some details;
  t.state <- State.fail t.state details;
  t.config.callbacks.on_error details

let reset_turn t =
  abort_in_flight t;
  t.processor <- EngineBackend.initial_processor_state;
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
      Utils.Log.debug1 "[ribosome engine] backend parsed, reconciling";
      t.processor <- processor;
      let existing = match t.last_template with Some x -> x | None -> root_template in
      let reconciled = match Reconciler.reconcile existing template with
        | Reconciler.Found t -> t
        | Reconciler.NotFound _ -> template
      in
      t.last_template <- Some reconciled;
      render_template t reconciled
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
  | Http.Failed _ -> t.abort <- None
  | Http.Complete ->
    t.abort <- None;
    Utils.Log.debug1 "[ribosome engine] stream complete";
    (match t.last_error with
    | Some _ -> ()
    | None ->
      match State.complete t.state with
      | Error message ->
        set_error t message
      | Ok state ->
        t.state <- state;
        t.config.callbacks.on_message_complete t.last_template)

and run_turn t user_message =
  reset_turn t;
  Utils.Log.debug "[ribosome engine] run_turn user_message" user_message;
  t.history <- t.history @ [{ role = User; content = user_message }];
  let context = {
    system_prompt =
      Prompt.create_llm_prompt
        t.config.templates
        t.config.assets
        t.config.goal_prompt
        None;
    messages = t.history;
  } in
  let request = t.config.request context in
  Utils.Log.debug "[ribosome engine] request url" request.url;
  Utils.Log.debug "[ribosome engine] request body" request.body;
  let controller = Fetch.AbortController.make () in
  t.abort <- Some (fun () -> Fetch.AbortController.abort controller);
  Http.post
    ~signal:(Some (Fetch.AbortController.signal controller))
    ~url:request.url
    ~headers:request.headers
    ~body:request.body
    ~on_chunk:(on_chunk t)
    ~on_done:(on_done t)
    ~on_error:(set_error t)

and kick_off t =
  Utils.Log.debug1 "[ribosome engine] kick_off";
  recover_if_errored t;
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
    let tree_json =
      SubmitTypes.serialise_template root_template
      |> Melange_json.to_string
    in
    let user_message =
      String.concat "\n\n" [
        Prompt.first_turn_user_instructions;
        "Current tree:";
        tree_json;
      ]
    in
    Utils.Log.debug "[ribosome engine] kick_off user_message" user_message;
    run_turn t user_message

and recover_if_errored t =
  match t.last_error with
  | None -> ()
  | Some _ ->
    Utils.Log.debug1 "[ribosome engine] recovering from errored state";
    t.state <- State.restart t.state;
    t.last_error <- None

and submit t payload =
  Utils.Log.debug "[ribosome engine] submit payload template_id" payload.SubmitTypes.template_id;
  recover_if_errored t;
  t.config.callbacks.on_submit payload;
  let tree_json =
    match t.last_template with
    | None ->
      SubmitTypes.serialise_template root_template
      |> Melange_json.to_string
    | Some template ->
      let template_with_input = SubmitTypes.inject_user_input template payload.SubmitTypes.values in
      SubmitTypes.serialise_template template_with_input
      |> Melange_json.to_string
  in
  let user_message =
    String.concat "\n\n" [
      Prompt.later_turn_user_instructions;
      "Current tree:";
      tree_json;
    ]
  in
  Utils.Log.debug "[ribosome engine] submit serialized tree" user_message;
  let prompt =
    Prompt.create_llm_prompt
      t.config.templates
      t.config.assets
      t.config.goal_prompt
      None
  in
  match State.kick_off t.state ~prompt with
  | Error message ->
    Utils.Log.debug "[ribosome engine] submit kick_off rejected" message;
    set_error t message
  | Ok state ->
    t.state <- state;
    run_turn t user_message

let reset t =
  abort_in_flight t;
  t.state <- State.AnyState State.Idle;
  t.history <- [];
  t.last_template <- Some root_template;
  t.processor <- EngineBackend.initial_processor_state;
  t.last_error <- None;
  t.abort <- None

let create config =
  let t = create_runtime config in
  {
    start = (fun () -> kick_off t);
    reset = (fun () -> reset t);
    history = (fun () -> t.history);
  }
