use std::collections::BTreeMap;

use crate::{
    FormField, InputValue, Template,
    protocol::{ServerEnvelope, ServerMessage},
};

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Model {
    pub session: Option<Session>,
    pub generation: GenerationState,
    pub rejection: Option<EventRejection>,
    pub local: BTreeMap<String, WidgetState>,
    pub focus: FocusState,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Session {
    pub id: String,
    pub revision: i64,
    pub tree: Option<Template>,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub enum GenerationState {
    #[default]
    Idle,
    Active {
        turn_id: String,
    },
    Failed {
        turn_id: String,
        message: String,
    },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct EventRejection {
    pub event_id: String,
    pub reason: String,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub enum FocusState {
    #[default]
    None,
    Focused(String),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum WidgetState {
    Input { value: String, cursor: usize },
    Select { selected: Option<String> },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Message {
    Server(ServerEnvelope),
    Terminal(TerminalEvent),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TerminalEvent {
    FocusNext,
    FocusPrevious,
    Activate,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Effect {
    Activate { id: String },
}

pub fn update(message: Message, mut model: Model) -> (Model, Vec<Effect>) {
    match message {
        Message::Server(envelope) => {
            reduce_server(envelope.message, &mut model);
            (model, Vec::new())
        }
        Message::Terminal(event) => reduce_terminal(event, model),
    }
}

fn reduce_server(message: ServerMessage, model: &mut Model) {
    match message {
        ServerMessage::SessionState {
            session_id,
            revision,
            tree,
        } => {
            model.local = local_state_for_tree(tree.as_ref(), &model.local);
            model.focus = focus_for_tree(tree.as_ref(), &model.focus);
            model.session = Some(Session {
                id: session_id,
                revision,
                tree,
            });
            model.generation = GenerationState::Idle;
            model.rejection = None;
        }
        ServerMessage::TemplateUpdate {
            session_id,
            revision,
            tree,
        } => {
            let current_local = model.local.clone();
            let current_focus = model.focus.clone();
            if let Some(session) = &mut model.session
                && session.id == session_id
                && revision >= session.revision
            {
                session.revision = revision;
                session.tree = Some(tree);
                let next_local = local_state_for_tree(session.tree.as_ref(), &current_local);
                let next_focus = focus_for_tree(session.tree.as_ref(), &current_focus);
                model.local = next_local;
                model.focus = next_focus;
            }
        }
        ServerMessage::GenerationStarted {
            session_id,
            turn_id,
        } => {
            if session_matches(model, &session_id) {
                model.generation = GenerationState::Active { turn_id };
            }
        }
        ServerMessage::GenerationCompleted {
            session_id,
            turn_id,
        } => {
            if session_matches(model, &session_id) && active_turn_matches(model, &turn_id) {
                model.generation = GenerationState::Idle;
            }
        }
        ServerMessage::GenerationFailed {
            session_id,
            turn_id,
            message,
        } => {
            if session_matches(model, &session_id) && active_turn_matches(model, &turn_id) {
                model.generation = GenerationState::Failed { turn_id, message };
            }
        }
        ServerMessage::EventRejected {
            session_id,
            event_id,
            reason,
        } => {
            if session_matches(model, &session_id) {
                model.rejection = Some(EventRejection { event_id, reason });
            }
        }
    }
}

fn reduce_terminal(event: TerminalEvent, mut model: Model) -> (Model, Vec<Effect>) {
    let focus_order = model
        .session
        .as_ref()
        .and_then(|session| session.tree.as_ref())
        .map(focus_order)
        .unwrap_or_default();

    match event {
        TerminalEvent::FocusNext => {
            model.focus = advance_focus(&focus_order, &model.focus, true);
            (model, Vec::new())
        }
        TerminalEvent::FocusPrevious => {
            model.focus = advance_focus(&focus_order, &model.focus, false);
            (model, Vec::new())
        }
        TerminalEvent::Activate => {
            let effect = match &model.focus {
                FocusState::Focused(id) => Some(Effect::Activate { id: id.clone() }),
                FocusState::None => None,
            };
            match effect {
                Some(effect) => (model, vec![effect]),
                None => (model, Vec::new()),
            }
        }
    }
}

fn focus_for_tree(tree: Option<&Template>, current: &FocusState) -> FocusState {
    match tree {
        Some(tree) => {
            let order = focus_order(tree);
            match current {
                FocusState::Focused(id) if order.contains(id) => FocusState::Focused(id.clone()),
                FocusState::None | FocusState::Focused(_) => match order.first() {
                    Some(id) => FocusState::Focused(id.clone()),
                    None => FocusState::None,
                },
            }
        }
        None => FocusState::None,
    }
}

fn advance_focus(order: &[String], current: &FocusState, forward: bool) -> FocusState {
    if order.is_empty() {
        return FocusState::None;
    }

    let index = match current {
        FocusState::Focused(id) => order.iter().position(|candidate| candidate == id),
        FocusState::None => None,
    };
    let next_index = match (index, forward) {
        (Some(index), true) => (index + 1) % order.len(),
        (Some(0), false) => order.len() - 1,
        (Some(index), false) => index - 1,
        (None, true) => 0,
        (None, false) => order.len() - 1,
    };

    FocusState::Focused(order[next_index].clone())
}

fn focus_order(template: &Template) -> Vec<String> {
    let mut order = Vec::new();
    collect_focusable_ids(template, &mut order);
    order
}

fn collect_focusable_ids(template: &Template, order: &mut Vec<String>) {
    match template {
        Template::Text { .. } => {}
        Template::Container { children, .. } => {
            for child in children {
                collect_focusable_ids(child, order);
            }
        }
        Template::Submittable { fields, button, .. } => {
            for field in fields {
                match field {
                    FormField::Input(input) => order.push(input.id.clone()),
                    FormField::Select(select) => order.push(select.id.clone()),
                }
            }
            if let Some(button) = button {
                order.push(button.id.clone());
            }
        }
    }
}

fn session_matches(model: &Model, session_id: &str) -> bool {
    matches!(&model.session, Some(session) if session.id == session_id)
}

fn active_turn_matches(model: &Model, turn_id: &str) -> bool {
    matches!(&model.generation, GenerationState::Active { turn_id: active } if active == turn_id)
}

fn local_state_for_tree(
    tree: Option<&Template>,
    current: &BTreeMap<String, WidgetState>,
) -> BTreeMap<String, WidgetState> {
    let mut next = BTreeMap::new();

    if let Some(tree) = tree {
        collect_local_state(tree, current, &mut next);
    }

    next
}

fn collect_local_state(
    template: &Template,
    current: &BTreeMap<String, WidgetState>,
    next: &mut BTreeMap<String, WidgetState>,
) {
    match template {
        Template::Text { .. } => {}
        Template::Container { children, .. } => {
            for child in children {
                collect_local_state(child, current, next);
            }
        }
        Template::Submittable { fields, .. } => {
            for field in fields {
                match field {
                    FormField::Input(input) => {
                        let state = match current.get(&input.id) {
                            Some(WidgetState::Input { value, cursor }) => WidgetState::Input {
                                value: value.clone(),
                                cursor: *cursor,
                            },
                            Some(WidgetState::Select { .. }) | None => WidgetState::Input {
                                value: input_value(input.value.as_ref()),
                                cursor: 0,
                            },
                        };
                        next.insert(input.id.clone(), state);
                    }
                    FormField::Select(select) => {
                        let state = match current.get(&select.id) {
                            Some(WidgetState::Select { selected }) => WidgetState::Select {
                                selected: selected.clone(),
                            },
                            Some(WidgetState::Input { .. }) | None => WidgetState::Select {
                                selected: select.selected.clone(),
                            },
                        };
                        next.insert(select.id.clone(), state);
                    }
                }
            }
        }
    }
}

fn input_value(value: Option<&InputValue>) -> String {
    match value {
        Some(InputValue::String(value)) => value.clone(),
        Some(InputValue::Integer(value)) => value.to_string(),
        None => String::new(),
    }
}

#[cfg(test)]
mod tests {
    use crate::{
        Button, Direction, FormField, Input, Select, Template,
        protocol::{ProtocolVersion, ServerEnvelope, ServerMessage},
    };

    use super::{
        Effect, FocusState, GenerationState, Message, Model, Session, TerminalEvent, WidgetState,
        update,
    };

    fn server(message: ServerMessage) -> Message {
        Message::Server(ServerEnvelope {
            protocol_version: ProtocolVersion::V1,
            message,
        })
    }

    fn session_model() -> Model {
        update(
            server(ServerMessage::SessionState {
                session_id: String::from("session-1"),
                revision: 3,
                tree: None,
            }),
            Model::default(),
        )
        .0
    }

    #[test]
    fn newer_template_updates_replace_the_authoritative_tree() {
        let tree = Template::Container {
            id: String::from("root"),
            direction: Direction::Vertical,
            children: Vec::new(),
        };
        let model = update(
            server(ServerMessage::TemplateUpdate {
                session_id: String::from("session-1"),
                revision: 4,
                tree: tree.clone(),
            }),
            session_model(),
        )
        .0;

        assert_eq!(
            model.session,
            Some(Session {
                id: String::from("session-1"),
                revision: 4,
                tree: Some(tree),
            })
        );
    }

    #[test]
    fn stale_or_foreign_server_messages_leave_model_unchanged() {
        let model = session_model();
        let stale = ServerMessage::TemplateUpdate {
            session_id: String::from("session-1"),
            revision: 2,
            tree: Template::Text {
                id: String::from("title"),
                text_type: crate::TextType::H1,
                content: String::from("Stale"),
            },
        };
        let foreign = ServerMessage::GenerationStarted {
            session_id: String::from("session-2"),
            turn_id: String::from("turn-1"),
        };

        assert_eq!(update(server(stale), model.clone()).0, model);
        assert_eq!(update(server(foreign), model.clone()).0, model);
    }

    #[test]
    fn matching_lifecycle_messages_update_generation_state() {
        let active = update(
            server(ServerMessage::GenerationStarted {
                session_id: String::from("session-1"),
                turn_id: String::from("turn-1"),
            }),
            session_model(),
        )
        .0;
        let completed = update(
            server(ServerMessage::GenerationCompleted {
                session_id: String::from("session-1"),
                turn_id: String::from("turn-1"),
            }),
            active,
        )
        .0;

        assert_eq!(completed.generation, GenerationState::Idle);
    }

    #[test]
    fn template_updates_preserve_compatible_widget_state() {
        let initial_tree = Template::Submittable {
            id: String::from("form"),
            fields: vec![
                FormField::Input(Input {
                    id: String::from("answer"),
                    value: Some(crate::InputValue::String(String::from("Generated"))),
                }),
                FormField::Select(Select {
                    id: String::from("choice"),
                    label: String::from("Choice"),
                    options: Vec::new(),
                    selected: Some(String::from("one")),
                }),
            ],
            button: None,
        };
        let mut model = update(
            server(ServerMessage::SessionState {
                session_id: String::from("session-1"),
                revision: 1,
                tree: Some(initial_tree),
            }),
            Model::default(),
        )
        .0;
        model.local.insert(
            String::from("answer"),
            WidgetState::Input {
                value: String::from("Edited"),
                cursor: 3,
            },
        );

        let next_tree = Template::Submittable {
            id: String::from("form"),
            fields: vec![
                FormField::Input(Input {
                    id: String::from("answer"),
                    value: Some(crate::InputValue::String(String::from("Replacement"))),
                }),
                FormField::Input(Input {
                    id: String::from("choice"),
                    value: None,
                }),
            ],
            button: None,
        };
        let updated = update(
            server(ServerMessage::TemplateUpdate {
                session_id: String::from("session-1"),
                revision: 2,
                tree: next_tree,
            }),
            model,
        )
        .0;

        assert_eq!(
            updated.local.get("answer"),
            Some(&WidgetState::Input {
                value: String::from("Edited"),
                cursor: 3,
            })
        );
        assert_eq!(
            updated.local.get("choice"),
            Some(&WidgetState::Input {
                value: String::new(),
                cursor: 0,
            })
        );
    }

    #[test]
    fn terminal_navigation_cycles_focus_and_activates_the_focused_component() {
        let tree = Template::Submittable {
            id: String::from("form"),
            fields: vec![
                FormField::Input(Input {
                    id: String::from("answer"),
                    value: None,
                }),
                FormField::Select(Select {
                    id: String::from("choice"),
                    label: String::from("Choice"),
                    options: Vec::new(),
                    selected: None,
                }),
            ],
            button: Some(Button {
                id: String::from("submit"),
                label: String::from("Submit"),
                action: String::from("Submit"),
                disabled: None,
            }),
        };
        let model = update(
            server(ServerMessage::SessionState {
                session_id: String::from("session-1"),
                revision: 1,
                tree: Some(tree),
            }),
            Model::default(),
        )
        .0;
        let focused = update(Message::Terminal(TerminalEvent::FocusNext), model).0;
        let (activated, effects) = update(Message::Terminal(TerminalEvent::Activate), focused);

        assert_eq!(activated.focus, FocusState::Focused(String::from("choice")));
        assert_eq!(
            effects,
            vec![Effect::Activate {
                id: String::from("choice"),
            }]
        );
    }
}
