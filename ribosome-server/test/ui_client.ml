open Ribosome_server_lib

(* Protocol-only UI client for testing.
   Talks directly to Ui_runtime via Ui_protocol messages.
   Tracks latest revision and tree, generates revision-correct events,
   supports reconnect from a known revision. *)

type client_state = {
  session_id : string;
  mutable revision : int;
  mutable tree : string option;
  mutable mode : string;
  mutable generation_id : string option;
  mutable connected : bool;
  event_counter : int ref;
}

(* Collected inbound messages for test assertions *)
type inbox = {
  mutable session_states : Ui_protocol.session_state list;
  mutable template_updates : Ui_protocol.template_update list;
  mutable rejections : Ui_protocol.event_rejection list;
  mutable user_turns : (string * string * string) list;
}

let create_inbox () =
  {
    session_states = [];
    template_updates = [];
    rejections = [];
    user_turns = [];
  }

let clear_inbox (i : inbox) =
  i.session_states <- [];
  i.template_updates <- [];
  i.rejections <- [];
  i.user_turns <- []

let make_client ~session_id =
  {
    session_id;
    revision = 0;
    tree = None;
    mode = "";
    generation_id = None;
    connected = false;
    event_counter = ref 0;
  }

(* Build a broadcast that captures messages into an inbox *)
let make_inbox_broadcast (i : inbox) =
  {
    Ui_runtime.broadcast_template_update =
      (fun ~session_id ~revision ~tree ->
        i.template_updates <-
          { Ui_protocol.session_id; revision; tree } :: i.template_updates);
    broadcast_session_state =
      (fun ~session_id ~mode ~revision ~tree ~generation_id ->
        i.session_states <-
          { Ui_protocol.session_id; mode; revision; tree; generation_id }
          :: i.session_states);
    broadcast_event_rejection =
      (fun ~session_id ~event_id ~reason ->
        i.rejections <-
          { Ui_protocol.session_id; event_id; reason } :: i.rejections);
    send_user_turn =
      (fun ~session_id ~tree ~event ->
        i.user_turns <- (session_id, tree, event) :: i.user_turns);
  }

(* Apply inbound session_state to client state *)
let apply_session_state (c : client_state) (s : Ui_protocol.session_state) =
  c.revision <- s.revision;
  c.tree <- s.tree;
  c.mode <- s.mode;
  c.generation_id <- s.generation_id;
  c.connected <- true

(* Apply inbound template_update to client state *)
let apply_template_update (c : client_state) (t : Ui_protocol.template_update) =
  c.revision <- t.revision;
  c.tree <- Some t.tree

(* Drain inbox into client state, return count of messages processed.
   Does not clear user_turns or rejections — those are checked separately. *)
let drain_inbox (c : client_state) (i : inbox) : int =
  let n_states = Stdlib.List.length i.session_states in
  let n_updates = Stdlib.List.length i.template_updates in
  Stdlib.List.iter (apply_session_state c) (Stdlib.List.rev i.session_states);
  Stdlib.List.iter (apply_template_update c)
    (Stdlib.List.rev i.template_updates);
  i.session_states <- [];
  i.template_updates <- [];
  n_states + n_updates

(* Send attach (initial or reconnect from known revision) *)
let send_attach (c : client_state) (runtime : Ui_runtime.t) ~reconnect =
  let msg =
    Ui_protocol.Attach
      {
        session_id = c.session_id;
        revision = (if reconnect then Some c.revision else None);
      }
  in
  match Ui_runtime.handle_message runtime msg with
  | Ok () -> ()
  | Error e ->
      failwith
        ("attach failed: "
        ^
        match e with
        | Ui_runtime.InvalidSession -> "invalid session"
        | Ui_runtime.InvalidNonce -> "invalid nonce"
        | Ui_runtime.NoActiveSession -> "no active session"
        | Ui_runtime.EventError s -> s)

(* Generate a unique event ID *)
let next_event_id (c : client_state) =
  incr c.event_counter;
  "evt-" ^ string_of_int !(c.event_counter)

(* Send a component event with the current revision *)
let send_event (c : client_state) (runtime : Ui_runtime.t) ~target_id ~kind
    ~value =
  let msg =
    Ui_protocol.ComponentEvent
      {
        session_id = c.session_id;
        revision = c.revision;
        event_id = next_event_id c;
        target_id;
        kind;
        value;
      }
  in
  Ui_runtime.handle_message runtime msg

let send_change c runtime ~target_id ~value =
  send_event c runtime ~target_id ~kind:Ui_protocol.Change ~value:(Some value)

let send_click c runtime ~target_id =
  send_event c runtime ~target_id ~kind:Ui_protocol.Click ~value:None

let send_submit c runtime ~target_id =
  send_event c runtime ~target_id ~kind:Ui_protocol.Submit ~value:None

let send_disconnect (c : client_state) (runtime : Ui_runtime.t) =
  let msg = Ui_protocol.Disconnect { session_id = c.session_id } in
  (match Ui_runtime.handle_message runtime msg with
  | Ok () -> ()
  | Error _ -> ());
  c.connected <- false
