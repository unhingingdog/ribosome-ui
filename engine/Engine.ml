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

let create config = {
  config;
  renderer = EngineFrontendReact.create_renderer config.root;
  state = State.AnyState State.Idle;
  history = [];
  processor = EngineBackend.initial_processor_state;
  last_template = None;
  last_error = None;
}

let set_error t details =
  t.last_error <- Some details;
  t.state <- State.fail t.state details;
  t.config.callbacks.on_error details

let reset_turn t =
  t.processor <- EngineBackend.initial_processor_state;
  t.last_template <- None;
  t.last_error <- None

let on_chunk _t _payload = ()

let on_done _t _reason = ()

let run_turn t ~user_message ~interaction_goal =
  reset_turn t;
  t.history <- t.history @ [{ role = User; content = user_message }];
  let context = {
    system_prompt =
      Prompt.create_llm_prompt
        t.config.templates
        t.config.goal_prompt
        interaction_goal;
    messages = t.history;
  } in
  let request = t.config.request context in
  Http.post
    ~url:request.url
    ~headers:request.headers
    ~body:request.body
    ~on_chunk:(on_chunk t)
    ~on_done:(on_done t)
    ~on_error:(set_error t)

let kick_off t =
  let prompt =
    Prompt.create_llm_prompt
      t.config.templates
      t.config.goal_prompt
      None
  in
  match State.kick_off t.state ~prompt with
  | Error message ->
    set_error t message
  | Ok state ->
    t.state <- state;
    run_turn t ~user_message:t.config.goal_prompt ~interaction_goal:None
