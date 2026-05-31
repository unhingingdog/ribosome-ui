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

let empty_history = { State.messages = [] }

let create config = {
  config;
  renderer = EngineFrontendReact.create_renderer config.root;
  state = State.AnyState (State.Idle empty_history);
  history = [];
  processor = EngineBackend.initial_processor_state;
  last_template = None;
  last_error = None;
}
