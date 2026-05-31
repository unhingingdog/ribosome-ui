# Ribosome UI Architecture

This document describes the Phase 2 architecture target: streamed structured JSON from an inference backend becomes a rendered React UI, and structured user submissions loop back into the next model turn.

Telomere is treated as a black box here: it receives incremental JSON text and returns enough completion data to parse the current partial response when possible.

## Module Map

```mermaid
flowchart TD
  Consumer[Consumer App]
  Facade[JS/NPM Facade\nfuture stable public API]
  Engine[Engine.ml\nmutable runtime + orchestration]
  EngineTypes[EngineTypes.ml\nconfig, status, chat/request types]
  State[State.ml\npure typed phase machine]
  Prompt[Prompt.ml\nprompt generator]
  Http[Http.ml\nfetch POST helper]
  Stream[Stream.ml\nSSE parser + stream pump]
  Backend[EngineBackend.ml\nchunk -> template result]
  Telomere[Telomere\nblack-box partial JSON closer]
  Parser[Parser.ml\nJSON -> template tree]
  Types[Types.ml\ntemplate model]
  SubmitTypes[SubmitTypes.ml\nuser submission model]
  Frontend[EngineFrontendReact.ml\ntemplate -> React element]
  React[React Root]

  Consumer --> Facade
  Facade --> Engine
  Engine --> EngineTypes
  Engine --> State
  Engine --> Prompt
  Engine --> Http
  Http --> Stream
  Stream --> Engine
  Engine --> Backend
  Backend --> Telomere
  Backend --> Parser
  Parser --> Types
  Engine --> Frontend
  Frontend --> Types
  Frontend --> SubmitTypes
  Frontend --> React
  Frontend --> Engine
```

## Runtime Data Flow

```mermaid
sequenceDiagram
  participant App as Consumer App
  participant Facade as JS Facade
  participant Engine as Engine.ml
  participant State as State.ml
  participant Prompt as Prompt.ml
  participant Http as Http.ml
  participant Stream as Stream.ml
  participant Backend as EngineBackend.ml
  participant Telomere as Telomere
  participant Parser as Parser.ml
  participant Frontend as EngineFrontendReact.ml
  participant React as React Root

  App->>Facade: engine.send(userText)
  Facade->>Engine: send t userText
  Engine->>Prompt: create_llm_prompt templates goal interaction
  Engine->>State: transition_idle Idle Send
  State-->>Engine: StartSending Sending
  Engine->>Http: post requestConfig callbacks
  Http->>Stream: pump response.body reader

  loop SSE data frames
    Stream-->>Engine: on_chunk(delta)
    Engine->>Backend: handle_chunk delta processor
    Backend->>Telomere: feed partial JSON
    Telomere-->>Backend: Pending / Completion / Corrupted
    alt JSON closable
      Backend->>Parser: parse completed JSON
      Parser-->>Backend: template tree
      Backend-->>Engine: Parsed(template, processor)
      Engine->>Engine: store last_template
      Engine->>Frontend: render_template_with_submit template on_submit
      Frontend->>React: render element tree
    else JSON pending
      Backend-->>Engine: Pending(processor)
      Engine->>Engine: store processor only
    else corrupted or hard parse failure
      Backend-->>Engine: Failed(message, processor)
      Engine->>State: transition_* ErrOut
      Engine->>App: on_error(message)
    end
  end

  Stream-->>Engine: on_done()
  Engine->>State: transition_receiving Complete
  State-->>Engine: Done Idle
  Engine->>App: on_message_complete(last_template)
```

## Structured Submit Loop

```mermaid
sequenceDiagram
  participant React as Rendered Submittable Component
  participant Frontend as EngineFrontendReact.ml
  participant Engine as Engine.ml
  participant App as Consumer App
  participant Prompt as Prompt/History Builder
  participant Http as HTTP Stream

  React->>Frontend: on_submit(submission_payload)
  Frontend->>Engine: SubmitTypes.submission_payload
  Engine->>App: callbacks.on_submit(payload)
  Engine->>Engine: read last_template
  Engine->>Prompt: serialize structured user turn
  Note over Engine,Prompt: user message includes submission values keyed by input id\nand previous assistant template context
  Engine->>Http: start next streamed request
```

The submission payload is user-authored runtime data, not part of the assistant-authored template model.

```mermaid
classDiagram
  class submittable {
    string kind
    string id
    input[] value
  }

  class submission_payload {
    string template_id
    submitted_input[] values
  }

  class submitted_input {
    string id
    submitted_value value
  }

  submittable : assistant-authored template
  submission_payload : user-authored runtime response
  submission_payload --> submitted_input
```

## Engine Runtime Store

`Engine.ml` is the effect boundary. It owns the mutable runtime state and interprets pure state transitions.

```mermaid
classDiagram
  class Engine_t {
    config
    renderer option
    mutable State.any_state state
    mutable chat_message[] history
    mutable Processor.processor_state processor
    mutable template option last_template
    mutable string option last_error
  }

  class State_any_state {
    existential typed state
  }

  class State_ml {
    transition_idle()
    transition_sending()
    transition_receiving()
    transition_errored()
  }

  Engine_t --> State_any_state
  Engine_t --> State_ml : calls pure transitions
```

The state machine does not know about HTTP, React, Telomere, prompts, or providers. It only models the logical phase:

```mermaid
stateDiagram-v2
  [*] --> Idle
  Idle --> Sending: Send
  Sending --> Receiving: StartRecv
  Sending --> Errored: ErrOut
  Receiving --> Receiving: Continue
  Receiving --> Idle: Complete
  Receiving --> Errored: ErrOut
  Errored --> Sending: Retry FailedSend
  Errored --> Receiving: Retry FailedRecv
  Errored --> Idle: Restart
```

## Public Package Boundary

The final npm package should expose a small JS/TS facade rather than raw Melange-generated OCaml shapes.

```mermaid
flowchart LR
  App[TypeScript Consumer]
  PublicAPI[Public JS/TS Facade]
  Internal[Melange-generated OCaml Internals]
  Engine[Engine.t]

  App --> PublicAPI
  PublicAPI --> Internal
  Internal --> Engine

  PublicAPI -.hides.-> Variants[OCaml variants, lists, ADTs]
```

Target public shape:

```ts
type RibosomeEngine = {
  send(prompt: string): Promise<void>;
  submit(payload: SubmissionPayload): Promise<void>;
  reset(): void;
  status(): EngineStatus;
  history(): ChatMessage[];
};
```

The facade should convert between JS-native objects and internal Melange values so consumers never construct OCaml ADTs or lists directly.

## Phase 2 Completion Checklist

```mermaid
flowchart TD
  A[Define engine public/internal config] --> B[Create Engine.t runtime store]
  B --> C[Implement state dispatch boundary]
  C --> D[Implement send text flow]
  D --> E[Stream chunks into backend]
  E --> F[Render parsed templates]
  F --> G[Wire submittable on_submit]
  G --> H[Serialize submission + last_template]
  H --> I[Start next streamed turn]
  I --> J[Add integration tests]
  J --> K[Build npm-facing facade]
  K --> L[Demo app / prototype parity]
```
