type lifecycle =
  | Starting
  | Ready
  | Closed

type generation = {
  turn: Codex_client.Turn.turn;
  cancellation_requested: bool;
}

type t = {
  id: string;
  thread: Codex_client.Thread.thread option;
  tree: Ribosome_core.Types.template option;
  revision: int;
  connections: string list;
  generation: generation option;
  lifecycle: lifecycle;
}

type error =
  | Thread_already_attached
  | Session_closed

type event_error =
  | Not_component_event
  | Wrong_session
  | Stale_revision
  | No_template
  | Unknown_component of string
  | Invalid_component_event

type generation_error =
  | Generation_session_closed
  | No_thread
  | Generation_already_active
  | No_active_generation
  | Cancellation_already_requested
  | Wrong_turn

type accepted_event = {
  event_id: string;
  event: Dream_protocol.ClientMessage.component_event;
}

let create id = {
  id;
  thread = None;
  tree = None;
  revision = 0;
  connections = [];
  generation = None;
  lifecycle = Starting;
}

let attach_thread session thread =
  match session.lifecycle, session.thread with
  | Closed, _ -> Error Session_closed
  | Starting, None -> Ok { session with thread = Some thread; lifecycle = Ready }
  | Starting, Some _ | Ready, _ -> Error Thread_already_attached

let connect session connection_id =
  match session.lifecycle with
  | Closed -> Error Session_closed
  | Starting | Ready ->
    let connections = if Stdlib.List.mem connection_id session.connections then session.connections
      else session.connections @ [connection_id]
    in
    Ok { session with connections }

let disconnect session connection_id = {
  session with connections = Stdlib.List.filter (fun id -> id <> connection_id) session.connections;
}

let close session = { session with lifecycle = Closed; connections = [] }

let start_generation session turn =
  match session.lifecycle, session.thread, session.generation with
  | Closed, _, _ -> Error Generation_session_closed
  | Starting, _, Some _ | Ready, _, Some _ -> Error Generation_already_active
  | Starting, None, None | Ready, None, None -> Error No_thread
  | Starting, Some _, None | Ready, Some _, None ->
    Ok { session with generation = Some { turn; cancellation_requested = false } }

let finish_generation session turn_id =
  match session.generation with
  | None -> Error No_active_generation
  | Some { turn; _ } when turn.id <> turn_id -> Error Wrong_turn
  | Some _ -> Ok { session with generation = None }

let complete_generation session turn_id = finish_generation session turn_id
let fail_generation session turn_id = finish_generation session turn_id

let request_cancellation session =
  match session.generation with
  | None -> Error No_active_generation
  | Some { cancellation_requested = true; _ } -> Error Cancellation_already_requested
  | Some generation ->
    Ok ({ session with generation = Some { generation with cancellation_requested = true } }, generation.turn)

let rec template_with_id id = function
  | Ribosome_core.Types.Container container ->
    if container.id = id then Some (Ribosome_core.Types.Container container)
    else find_in_children id container.children
  | Ribosome_core.Types.List list ->
    if list.id = id then Some (Ribosome_core.Types.List list)
    else find_in_children id list.children
  | Ribosome_core.Types.Submittable submittable ->
    if submittable.id = id then Some (Ribosome_core.Types.Submittable submittable) else None
  | Ribosome_core.Types.Image image when image.id = id -> Some (Ribosome_core.Types.Image image)
  | Ribosome_core.Types.Text text when text.id = id -> Some (Ribosome_core.Types.Text text)
  | Ribosome_core.Types.Badge badge when badge.id = id -> Some (Ribosome_core.Types.Badge badge)
  | Ribosome_core.Types.Stat stat when stat.id = id -> Some (Ribosome_core.Types.Stat stat)
  | Ribosome_core.Types.Divider divider when divider.id = id -> Some (Ribosome_core.Types.Divider divider)
  | Ribosome_core.Types.Broken _
  | Ribosome_core.Types.Image _
  | Ribosome_core.Types.Text _
  | Ribosome_core.Types.Badge _
  | Ribosome_core.Types.Stat _
  | Ribosome_core.Types.Divider _ -> None

and find_in_children id = function
  | [] -> None
  | template :: remaining ->
    (match template_with_id id template with
     | Some template -> Some template
     | None -> find_in_children id remaining)

let submittable_field_ids (submittable : Ribosome_core.Types.submittable) =
  Stdlib.List.map (function
    | Ribosome_core.Types.FieldInput input -> input.id
    | Ribosome_core.Types.FieldSelect select -> select.id
  ) submittable.value

let rec contains_button id = function
  | Ribosome_core.Types.Submittable { button = Some button; _ } -> button.id = id
  | Ribosome_core.Types.Container container -> Stdlib.List.exists (contains_button id) container.children
  | Ribosome_core.Types.List list -> Stdlib.List.exists (contains_button id) list.children
  | Ribosome_core.Types.Submittable { button = None; _ }
  | Ribosome_core.Types.Image _
  | Ribosome_core.Types.Text _
  | Ribosome_core.Types.Broken _
  | Ribosome_core.Types.Badge _
  | Ribosome_core.Types.Stat _
  | Ribosome_core.Types.Divider _ -> false

let rec contains_field id = function
  | Ribosome_core.Types.Submittable submittable -> Stdlib.List.mem id (submittable_field_ids submittable)
  | Ribosome_core.Types.Container container -> Stdlib.List.exists (contains_field id) container.children
  | Ribosome_core.Types.List list -> Stdlib.List.exists (contains_field id) list.children
  | Ribosome_core.Types.Image _
  | Ribosome_core.Types.Text _
  | Ribosome_core.Types.Broken _
  | Ribosome_core.Types.Badge _
  | Ribosome_core.Types.Stat _
  | Ribosome_core.Types.Divider _ -> false

let accepts_event tree = function
  | Dream_protocol.ClientMessage.Click { id } ->
    contains_button id tree
  | Dream_protocol.ClientMessage.Change { id; _ } ->
    contains_field id tree
  | Dream_protocol.ClientMessage.Submit { id; values } ->
    (match template_with_id id tree with
     | Some (Ribosome_core.Types.Submittable submittable) ->
       let field_ids = submittable_field_ids submittable in
       Stdlib.List.for_all (fun (field_id, _) -> Stdlib.List.mem field_id field_ids) values
     | Some _ | None -> false)

let reduce_event session = function
  | Dream_protocol.ClientMessage.Component_event { session_id; event_id; base_revision; event } ->
    if session_id <> session.id then Error Wrong_session
    else if base_revision <> session.revision then Error Stale_revision
    else
      (match session.tree with
       | None -> Error No_template
       | Some tree ->
         if accepts_event tree event then Ok { event_id; event }
         else
           let id = match event with
             | Dream_protocol.ClientMessage.Click { id }
             | Dream_protocol.ClientMessage.Change { id; _ }
             | Dream_protocol.ClientMessage.Submit { id; _ } -> id
           in
           if Stdlib.List.mem id (Ribosome_core.Traversal.ids tree) then Error Invalid_component_event
           else Error (Unknown_component id))
  | Dream_protocol.ClientMessage.New_session
  | Dream_protocol.ClientMessage.Resume_session _
  | Dream_protocol.ClientMessage.Cancel _ -> Error Not_component_event
