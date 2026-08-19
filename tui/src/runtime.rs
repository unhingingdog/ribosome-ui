use std::{io, thread, time::Duration};

use crossterm::{
    event::{
        self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEvent, KeyEventKind,
        KeyModifiers, MouseButton, MouseEvent, MouseEventKind,
    },
    execute,
    terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode},
};
use ratatui::{Terminal, backend::CrosstermBackend, layout::Rect, widgets::Paragraph};

use crate::{
    application::{GenerationState, InputEvent, Message, Model, TerminalEvent, update},
    component_registry::{ComponentRegistry, Interaction, Registry, RenderContext, interaction_at},
    debug_log,
    protocol::{ClientEnvelope, ClientMessage, ProtocolVersion},
    websocket::{DreamConnection, ReceiveResult, TransportError},
};

pub struct RuntimeConfig {
    pub url: String,
    pub initial_prompt: String,
}

#[derive(Debug)]
pub enum RuntimeError {
    Io(io::Error),
    Transport(TransportError),
    BlankInitialPrompt,
}

pub fn run(config: RuntimeConfig) -> Result<(), RuntimeError> {
    if config.initial_prompt.trim().is_empty() {
        return Err(RuntimeError::BlankInitialPrompt);
    }

    let mut terminal = TerminalGuard::enter()?;
    let mut model = Model::default();
    let mut connection = connect(&config, &model)?;
    let mut event_sequence = 0_u64;

    loop {
        terminal.draw(&model)?;

        if event::poll(Duration::from_millis(16)).map_err(RuntimeError::Io)? {
            let messages = match event::read().map_err(RuntimeError::Io)? {
                Event::Key(key) if should_quit(key) => return Ok(()),
                Event::Key(key) => terminal_message(key, &model).into_iter().collect(),
                Event::Mouse(mouse) => mouse_messages(mouse, &model, terminal.area()?),
                Event::FocusGained | Event::FocusLost | Event::Paste(_) | Event::Resize(_, _) => {
                    Vec::new()
                }
            };
            for message in messages {
                debug_log::write("TUI event", &format!("{message:?}"));
                let (next_model, effects) = update(message, model);
                model = next_model;
                for effect in effects {
                    debug_log::write("TUI effect", &format!("{effect:?}"));
                    event_sequence += 1;
                    connection
                        .execute(effect, &model, format!("event-{event_sequence}"))
                        .map_err(RuntimeError::Transport)?;
                }
            }
        }

        match connection.try_receive() {
            Ok(ReceiveResult::ServerMessage(message)) => {
                model = update(Message::Server(message), model).0;
            }
            Ok(ReceiveResult::Pending | ReceiveResult::Ignored) => {}
            Ok(ReceiveResult::Disconnected) => {
                thread::sleep(Duration::from_millis(250));
                connection = connect(&config, &model)?;
            }
            Err(error) => return Err(RuntimeError::Transport(error)),
        }
    }
}

fn mouse_messages(mouse: MouseEvent, model: &Model, area: Rect) -> Vec<Message> {
    if mouse.kind != MouseEventKind::Down(MouseButton::Left) {
        return Vec::new();
    }
    let Some(tree) = model
        .session
        .as_ref()
        .and_then(|session| session.tree.as_ref())
    else {
        return Vec::new();
    };
    let (content_area, _) = view_areas(area);
    match interaction_at(tree, content_area, mouse.column, mouse.row) {
        Some(Interaction::Focus(id)) => vec![Message::Terminal(TerminalEvent::Focus(id))],
        Some(Interaction::Activate(id)) => vec![
            Message::Terminal(TerminalEvent::Focus(id)),
            Message::Terminal(TerminalEvent::Activate),
        ],
        None => Vec::new(),
    }
}

fn connect(config: &RuntimeConfig, model: &Model) -> Result<DreamConnection, RuntimeError> {
    let mut connection = DreamConnection::connect(&config.url)
        .map_err(|error| RuntimeError::Transport(TransportError::Websocket(error)))?;
    connection
        .set_nonblocking(true)
        .map_err(RuntimeError::Transport)?;
    connection
        .send(session_message(config, model))
        .map_err(RuntimeError::Transport)?;
    Ok(connection)
}

fn session_message(config: &RuntimeConfig, model: &Model) -> ClientEnvelope {
    let message = match &model.session {
        Some(session) => ClientMessage::ResumeSession {
            session_id: session.id.clone(),
        },
        None => ClientMessage::NewSession {
            initial_prompt: config.initial_prompt.clone(),
        },
    };

    ClientEnvelope {
        protocol_version: ProtocolVersion::V1,
        message,
    }
}

fn should_quit(key: KeyEvent) -> bool {
    key.code == KeyCode::Char('c') && key.modifiers.contains(KeyModifiers::CONTROL)
}

fn terminal_message(key: KeyEvent, model: &Model) -> Option<Message> {
    if !matches!(key.kind, KeyEventKind::Press | KeyEventKind::Repeat) {
        return None;
    }

    let event = match key.code {
        KeyCode::Tab => TerminalEvent::FocusNext,
        KeyCode::BackTab => TerminalEvent::FocusPrevious,
        KeyCode::Enter => TerminalEvent::Activate,
        KeyCode::Esc => TerminalEvent::Cancel,
        KeyCode::Left => TerminalEvent::Input(InputEvent::CursorLeft),
        KeyCode::Right => TerminalEvent::Input(InputEvent::CursorRight),
        KeyCode::Backspace => TerminalEvent::Input(InputEvent::Backspace),
        KeyCode::Delete => TerminalEvent::Input(InputEvent::Delete),
        KeyCode::Up => TerminalEvent::SelectPrevious,
        KeyCode::Down => TerminalEvent::SelectNext,
        KeyCode::Char('h') if !focused_input(model) => TerminalEvent::FocusPrevious,
        KeyCode::Char('l') if !focused_input(model) => TerminalEvent::FocusNext,
        KeyCode::Char('j') if focused_select(model) => TerminalEvent::SelectNext,
        KeyCode::Char('k') if focused_select(model) => TerminalEvent::SelectPrevious,
        KeyCode::Char('j') => TerminalEvent::FocusNext,
        KeyCode::Char('k') => TerminalEvent::FocusPrevious,
        KeyCode::Char(character) => TerminalEvent::Input(InputEvent::Insert(character)),
        KeyCode::Null
        | KeyCode::CapsLock
        | KeyCode::ScrollLock
        | KeyCode::NumLock
        | KeyCode::PrintScreen
        | KeyCode::Pause
        | KeyCode::Menu
        | KeyCode::KeypadBegin
        | KeyCode::Media(_)
        | KeyCode::Modifier(_) => return None,
        KeyCode::F(_)
        | KeyCode::Home
        | KeyCode::End
        | KeyCode::PageUp
        | KeyCode::PageDown
        | KeyCode::Insert => return None,
    };

    Some(Message::Terminal(event))
}

fn focused_input(model: &Model) -> bool {
    matches!(
        &model.focus,
        crate::application::FocusState::Focused(id)
            if matches!(model.local.get(id), Some(crate::application::WidgetState::Input { .. }))
    )
}

fn focused_select(model: &Model) -> bool {
    matches!(
        &model.focus,
        crate::application::FocusState::Focused(id)
            if matches!(model.local.get(id), Some(crate::application::WidgetState::Select { .. }))
    )
}

struct TerminalGuard {
    terminal: Terminal<CrosstermBackend<io::Stdout>>,
}

impl TerminalGuard {
    fn enter() -> Result<Self, RuntimeError> {
        enable_raw_mode().map_err(RuntimeError::Io)?;
        let mut stdout = io::stdout();
        execute!(stdout, EnterAlternateScreen, EnableMouseCapture).map_err(RuntimeError::Io)?;
        Terminal::new(CrosstermBackend::new(stdout))
            .map(|terminal| Self { terminal })
            .map_err(RuntimeError::Io)
    }

    fn draw(&mut self, model: &Model) -> Result<(), RuntimeError> {
        self.terminal
            .draw(|frame| {
                let (content_area, status_area) = view_areas(frame.area());
                if let Some(tree) = model
                    .session
                    .as_ref()
                    .and_then(|session| session.tree.as_ref())
                {
                    Registry.render(
                        tree,
                        &RenderContext {
                            local: &model.local,
                            focus: &model.focus,
                        },
                        content_area,
                        frame.buffer_mut(),
                    );
                }
                frame.render_widget(Paragraph::new(status_text(model)), status_area);
            })
            .map(|_| ())
            .map_err(RuntimeError::Io)
    }

    fn area(&self) -> Result<Rect, RuntimeError> {
        self.terminal
            .size()
            .map(|size| Rect::new(0, 0, size.width, size.height))
            .map_err(RuntimeError::Io)
    }
}

fn view_areas(area: Rect) -> (Rect, Rect) {
    if area.height == 0 {
        return (area, area);
    }
    (
        Rect::new(area.x, area.y, area.width, area.height - 1),
        Rect::new(area.x, area.y + area.height - 1, area.width, 1),
    )
}

fn status_text(model: &Model) -> String {
    match (&model.session, &model.generation) {
        (None, _) => String::from("Connecting to Dream…"),
        (Some(_), GenerationState::Active { .. }) => String::from("Generating UI…"),
        (Some(_), GenerationState::Failed { message, .. }) => {
            format!("Generation failed: {message}")
        }
        (Some(session), GenerationState::Idle) if session.tree.is_some() => String::from("Ready"),
        (Some(_), GenerationState::Idle) => String::from("Starting generation…"),
    }
}

impl Drop for TerminalGuard {
    fn drop(&mut self) {
        let _ = disable_raw_mode();
        let _ = execute!(
            self.terminal.backend_mut(),
            DisableMouseCapture,
            LeaveAlternateScreen
        );
    }
}

#[cfg(test)]
mod tests {
    use crossterm::event::{KeyCode, KeyEvent, KeyEventKind, KeyModifiers};
    use ratatui::{Terminal, backend::TestBackend};

    use crate::{
        Button, FormField, Input, Template,
        application::{Effect, InputEvent, Message, Model, TerminalEvent, update},
        component_registry::{ComponentRegistry, Registry, RenderContext},
        protocol::{
            ComponentEvent, ProtocolVersion, ServerEnvelope, ServerMessage, SubmittedValue,
        },
    };

    use super::{status_text, terminal_message};

    #[test]
    fn displays_connection_and_generation_status_without_a_tree() {
        assert_eq!(status_text(&Model::default()), "Connecting to Dream…");

        let model = Model {
            session: Some(crate::application::Session {
                id: String::from("session-1"),
                revision: 0,
                tree: None,
            }),
            generation: crate::application::GenerationState::Active {
                turn_id: String::from("turn-1"),
            },
            ..Model::default()
        };
        assert_eq!(status_text(&model), "Generating UI…");
    }

    #[test]
    fn maps_terminal_keys_to_reducer_messages() {
        let key = KeyEvent {
            code: KeyCode::Char('a'),
            modifiers: KeyModifiers::NONE,
            kind: KeyEventKind::Press,
            state: crossterm::event::KeyEventState::NONE,
        };

        assert_eq!(
            terminal_message(key, &Model::default()),
            Some(Message::Terminal(TerminalEvent::Input(InputEvent::Insert(
                'a'
            ))))
        );
    }

    #[test]
    fn maps_vim_navigation_keys_when_no_input_is_focused() {
        let key = KeyEvent {
            code: KeyCode::Char('j'),
            modifiers: KeyModifiers::NONE,
            kind: KeyEventKind::Press,
            state: crossterm::event::KeyEventState::NONE,
        };

        assert_eq!(
            terminal_message(key, &Model::default()),
            Some(Message::Terminal(TerminalEvent::FocusNext))
        );
    }

    #[test]
    fn renders_dream_state_and_emits_a_submit_from_terminal_interaction() {
        let tree = Template::Submittable {
            id: String::from("form"),
            fields: vec![FormField::Input(Input {
                id: String::from("answer"),
                value: None,
            })],
            button: Some(Button {
                kind: crate::ButtonKind::Button,
                id: String::from("submit"),
                label: String::from("Submit"),
                action: String::from("Submit"),
                disabled: None,
            }),
        };
        let model = update(
            Message::Server(ServerEnvelope {
                protocol_version: ProtocolVersion::V1,
                message: ServerMessage::SessionState {
                    session_id: String::from("session-1"),
                    revision: 1,
                    tree: Some(tree),
                },
            }),
            Model::default(),
        )
        .0;
        let model = update(
            Message::Terminal(TerminalEvent::Input(InputEvent::Insert('A'))),
            model,
        )
        .0;
        let model = update(Message::Terminal(TerminalEvent::FocusNext), model).0;
        let (model, effects) = update(Message::Terminal(TerminalEvent::Activate), model);
        let mut terminal = Terminal::new(TestBackend::new(12, 2)).expect("test terminal");

        terminal
            .draw(|frame| {
                let tree = model
                    .session
                    .as_ref()
                    .and_then(|session| session.tree.as_ref())
                    .expect("Dream tree");
                Registry.render(
                    tree,
                    &RenderContext {
                        local: &model.local,
                        focus: &model.focus,
                    },
                    frame.area(),
                    frame.buffer_mut(),
                );
            })
            .expect("rendered test terminal");

        assert_eq!(terminal.backend().buffer()[(2, 0)].symbol(), "A");
        assert_eq!(
            effects,
            vec![Effect::ComponentEvent(ComponentEvent::Submit {
                id: String::from("form"),
                values: vec![SubmittedValue {
                    id: String::from("answer"),
                    value: crate::InputValue::String(String::from("A")),
                }],
            })]
        );
    }
}
