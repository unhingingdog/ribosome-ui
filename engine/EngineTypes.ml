type public_status =
  | Idle
  | Sending
  | Receiving
  | Error of string

type chat_role =
  | User
  | Bot

type chat_message = {
  role: chat_role;
  content: string;
}

type request_context = {
  system_prompt: string;
  messages: chat_message list;
}

type request_config = {
  url: string;
  headers: (string * string) array;
  body: string;
}

type callbacks = {
  on_submit: SubmitTypes.submission_payload -> unit;
  on_message_complete: Types.template option -> unit;
  on_error: string -> unit;
}

type config = {
  root: EngineFrontendReact.dom_handle;
  components: EngineFrontendReact.component_registry;
  templates: Prompt.template_registry;
  goal_prompt: string;
  request: request_context -> request_config;
  callbacks: callbacks;
}

type handle = {
  send: string -> unit Js.Promise.t;
  submit: SubmitTypes.submission_payload -> unit Js.Promise.t;
  reset: unit -> unit;
  status: unit -> public_status;
  history: unit -> chat_message list;
}
