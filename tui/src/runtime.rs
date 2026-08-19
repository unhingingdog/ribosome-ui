use std::{io, thread, time::Duration};

use crossterm::{
    event::{self, Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers},
    execute,
    terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode},
};
use ratatui::{Terminal, backend::CrosstermBackend};

use crate::{
    application::{InputEvent, Message, Model, TerminalEvent, update},
    component_registry::{ComponentRegistry, Registry, RenderContext},
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

        if event::poll(Duration::from_millis(16)).map_err(RuntimeError::Io)?
            && let Event::Key(key) = event::read().map_err(RuntimeError::Io)?
        {
            if should_quit(key) {
                return Ok(());
            }
            if let Some(message) = terminal_message(key, &model) {
                let (next_model, effects) = update(message, model);
                model = next_model;
                for effect in effects {
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
            Ok(ReceiveResult::Disconnected) | Err(_) => {
                thread::sleep(Duration::from_millis(250));
                connection = connect(&config, &model)?;
            }
        }
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
        execute!(stdout, EnterAlternateScreen).map_err(RuntimeError::Io)?;
        Terminal::new(CrosstermBackend::new(stdout))
            .map(|terminal| Self { terminal })
            .map_err(RuntimeError::Io)
    }

    fn draw(&mut self, model: &Model) -> Result<(), RuntimeError> {
        self.terminal
            .draw(|frame| {
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
                        frame.area(),
                        frame.buffer_mut(),
                    );
                }
            })
            .map(|_| ())
            .map_err(RuntimeError::Io)
    }
}

impl Drop for TerminalGuard {
    fn drop(&mut self) {
        let _ = disable_raw_mode();
        let _ = execute!(self.terminal.backend_mut(), LeaveAlternateScreen);
    }
}

#[cfg(test)]
mod tests {
    use crossterm::event::{KeyCode, KeyEvent, KeyEventKind, KeyModifiers};

    use crate::application::{InputEvent, Message, Model, TerminalEvent};

    use super::terminal_message;

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
}
