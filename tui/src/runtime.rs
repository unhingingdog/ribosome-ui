use std::{io, thread, time::Duration};

use crossterm::{
    event::{
        self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEvent, KeyEventKind,
        KeyModifiers, MouseButton, MouseEvent, MouseEventKind,
    },
    execute,
    terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode},
};
use ratatui::{
    Terminal,
    backend::CrosstermBackend,
    layout::Rect,
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Paragraph, Widget},
};

use crate::{
    application::{GenerationState, InputEvent, Message, Model, TerminalEvent, update},
    component_registry::{ComponentRegistry, Interaction, Registry, RenderContext, interaction_at},
    debug_log,
    protocol::{ClientEnvelope, ClientMessage, ProtocolVersion},
    theme::Theme,
    websocket::{DreamConnection, ReceiveResult, TransportError},
};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum UiProfile {
    Conversation,
    Pr,
}

impl UiProfile {
    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "conversation" => Some(Self::Conversation),
            "pr" => Some(Self::Pr),
            _ => None,
        }
    }
}

pub struct RuntimeConfig {
    pub url: String,
    pub initial_prompt: String,
    pub profile: UiProfile,
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
        let shell = shell_areas(terminal.area()?, config.profile);
        let workspace = Theme::panel(workspace_title(config.profile)).inner(shell.workspace);
        model = update(
            Message::Viewport {
                width: workspace.width,
                height: workspace.height,
            },
            model,
        )
        .0;
        terminal.draw(&model, config.profile)?;

        if event::poll(Duration::from_millis(16)).map_err(RuntimeError::Io)? {
            let messages = match event::read().map_err(RuntimeError::Io)? {
                Event::Key(key) if should_quit(key) => return Ok(()),
                Event::Key(key) => terminal_message(key, &model).into_iter().collect(),
                Event::Mouse(mouse) => mouse_messages(mouse, &model, workspace),
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
    match mouse.kind {
        MouseEventKind::ScrollUp | MouseEventKind::ScrollDown => {
            let Some(tree) = model
                .session
                .as_ref()
                .and_then(|session| session.tree.as_ref())
            else {
                return Vec::new();
            };
            let Some(Interaction::Focus(id)) =
                interaction_at(tree, area, model.viewport.scroll_y, mouse.column, mouse.row)
            else {
                return vec![Message::Terminal(
                    if matches!(mouse.kind, MouseEventKind::ScrollUp) {
                        TerminalEvent::ScrollUp
                    } else {
                        TerminalEvent::ScrollDown
                    },
                )];
            };
            if matches!(
                model.local.get(&id),
                Some(crate::application::WidgetState::Diagram { .. })
            ) {
                return vec![
                    Message::Terminal(TerminalEvent::Focus(id)),
                    Message::Terminal(if matches!(mouse.kind, MouseEventKind::ScrollUp) {
                        TerminalEvent::DiagramZoomIn
                    } else {
                        TerminalEvent::DiagramZoomOut
                    }),
                ];
            }
            return vec![Message::Terminal(
                if matches!(mouse.kind, MouseEventKind::ScrollUp) {
                    TerminalEvent::ScrollUp
                } else {
                    TerminalEvent::ScrollDown
                },
            )];
        }
        MouseEventKind::Down(MouseButton::Left) => {}
        MouseEventKind::Down(MouseButton::Right)
        | MouseEventKind::Down(MouseButton::Middle)
        | MouseEventKind::Up(_)
        | MouseEventKind::Drag(_)
        | MouseEventKind::Moved
        | MouseEventKind::ScrollLeft
        | MouseEventKind::ScrollRight => return Vec::new(),
    }
    let Some(tree) = model
        .session
        .as_ref()
        .and_then(|session| session.tree.as_ref())
    else {
        return Vec::new();
    };
    match interaction_at(tree, area, model.viewport.scroll_y, mouse.column, mouse.row) {
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
        KeyCode::Left if focused_diagram(model) => TerminalEvent::DiagramPan { x: -10, y: 0 },
        KeyCode::Right if focused_diagram(model) => TerminalEvent::DiagramPan { x: 10, y: 0 },
        KeyCode::Up if focused_diagram(model) => TerminalEvent::DiagramPan { x: 0, y: -10 },
        KeyCode::Down if focused_diagram(model) => TerminalEvent::DiagramPan { x: 0, y: 10 },
        KeyCode::Left => TerminalEvent::Input(InputEvent::CursorLeft),
        KeyCode::Right => TerminalEvent::Input(InputEvent::CursorRight),
        KeyCode::Backspace => TerminalEvent::Input(InputEvent::Backspace),
        KeyCode::Delete => TerminalEvent::Input(InputEvent::Delete),
        KeyCode::PageUp => TerminalEvent::PageUp,
        KeyCode::PageDown => TerminalEvent::PageDown,
        KeyCode::Up => TerminalEvent::SelectPrevious,
        KeyCode::Down => TerminalEvent::SelectNext,
        KeyCode::Char('h') if focused_diagram(model) => TerminalEvent::DiagramPan { x: -10, y: 0 },
        KeyCode::Char('j') if focused_diagram(model) => TerminalEvent::DiagramPan { x: 0, y: 10 },
        KeyCode::Char('k') if focused_diagram(model) => TerminalEvent::DiagramPan { x: 0, y: -10 },
        KeyCode::Char('l') if focused_diagram(model) => TerminalEvent::DiagramPan { x: 10, y: 0 },
        KeyCode::Char('+') | KeyCode::Char('=') if focused_diagram(model) => {
            TerminalEvent::DiagramZoomIn
        }
        KeyCode::Char('-') if focused_diagram(model) => TerminalEvent::DiagramZoomOut,
        KeyCode::Char('0') if focused_diagram(model) => TerminalEvent::DiagramReset,
        KeyCode::Char('h') if !focused_input(model) => TerminalEvent::FocusPrevious,
        KeyCode::Char('l') if !focused_input(model) => TerminalEvent::FocusNext,
        KeyCode::Char('j') if focused_select(model) => TerminalEvent::SelectNext,
        KeyCode::Char('k') if focused_select(model) => TerminalEvent::SelectPrevious,
        KeyCode::Char('j') => TerminalEvent::FocusNext,
        KeyCode::Char('k') => TerminalEvent::FocusPrevious,
        KeyCode::Char('u') if key.modifiers.contains(KeyModifiers::CONTROL) => {
            TerminalEvent::PageUp
        }
        KeyCode::Char('d') if key.modifiers.contains(KeyModifiers::CONTROL) => {
            TerminalEvent::PageDown
        }
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
        KeyCode::F(_) | KeyCode::Home | KeyCode::End | KeyCode::Insert => return None,
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

fn focused_diagram(model: &Model) -> bool {
    matches!(
        &model.focus,
        crate::application::FocusState::Focused(id)
            if matches!(model.local.get(id), Some(crate::application::WidgetState::Diagram { .. }))
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

    fn draw(&mut self, model: &Model, profile: UiProfile) -> Result<(), RuntimeError> {
        self.terminal
            .draw(|frame| {
                let shell = shell_areas(frame.area(), profile);
                Block::default()
                    .style(Style::default().bg(Theme::BACKGROUND))
                    .render(frame.area(), frame.buffer_mut());
                render_header(frame.buffer_mut(), shell.header, profile, model);
                if let Some(rail) = shell.rail {
                    render_rail(frame.buffer_mut(), rail, model);
                }
                if let Some(tree) = model
                    .session
                    .as_ref()
                    .and_then(|session| session.tree.as_ref())
                {
                    let panel = Theme::panel(workspace_title(profile));
                    let workspace = panel.inner(shell.workspace);
                    panel.render(shell.workspace, frame.buffer_mut());
                    Registry.render(
                        tree,
                        &RenderContext {
                            local: &model.local,
                            focus: &model.focus,
                            scroll_y: model.viewport.scroll_y,
                        },
                        workspace,
                        frame.buffer_mut(),
                    );
                    render_scrollbar(frame.buffer_mut(), workspace, model, tree);
                }
                render_footer(frame.buffer_mut(), shell.footer, model);
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

#[derive(Clone, Copy)]
struct ShellAreas {
    header: Rect,
    rail: Option<Rect>,
    workspace: Rect,
    footer: Rect,
}

fn shell_areas(area: Rect, profile: UiProfile) -> ShellAreas {
    let header_height = area.height.min(3);
    let footer_height = area.height.saturating_sub(header_height).min(2);
    let body = Rect::new(
        area.x,
        area.y + header_height,
        area.width,
        area.height.saturating_sub(header_height + footer_height),
    );
    let desktop_pr = profile == UiProfile::Pr && area.width >= 100 && area.height >= 24;
    let rail_width = if desktop_pr { 24.min(body.width) } else { 0 };
    ShellAreas {
        header: Rect::new(area.x, area.y, area.width, header_height),
        rail: desktop_pr.then(|| Rect::new(body.x, body.y, rail_width, body.height)),
        workspace: Rect::new(
            body.x + rail_width,
            body.y,
            body.width.saturating_sub(rail_width),
            body.height,
        ),
        footer: Rect::new(
            area.x,
            area.y + header_height + body.height,
            area.width,
            footer_height,
        ),
    }
}

fn render_header(
    buffer: &mut ratatui::buffer::Buffer,
    area: Rect,
    profile: UiProfile,
    model: &Model,
) {
    let profile_label = match profile {
        UiProfile::Conversation => "CONVERSATION",
        UiProfile::Pr => "PR REVIEW",
    };
    let status = match (&model.session, &model.generation) {
        (None, _) => Span::styled("● CONNECTING", Style::default().fg(Theme::VIOLET)),
        (Some(_), GenerationState::Active { .. }) => {
            Span::styled("● GENERATING", Style::default().fg(Theme::AMBER))
        }
        (Some(_), GenerationState::Failed { .. }) => {
            Span::styled("● FAILED", Style::default().fg(Theme::RED))
        }
        (Some(_), GenerationState::Idle) => {
            Span::styled("● READY", Style::default().fg(Theme::GREEN))
        }
    };
    Paragraph::new(Line::from(vec![
        Span::styled(" RIBOSOME ", Theme::title()),
        Span::styled(format!("/ {profile_label}"), Theme::muted()),
        Span::raw("  "),
        status,
    ]))
    .block(Block::default().style(Style::default().bg(Theme::SURFACE)))
    .render(area, buffer);
}

fn render_rail(buffer: &mut ratatui::buffer::Buffer, area: Rect, model: &Model) {
    let focused = match &model.focus {
        crate::application::FocusState::Focused(id) => humanize_id(id),
        crate::application::FocusState::None => String::from("None"),
    };
    let state = match (&model.session, &model.generation) {
        (None, _) => "Connecting",
        (Some(_), GenerationState::Active { .. }) => "Generating",
        (Some(_), GenerationState::Failed { .. }) => "Failed",
        (Some(_), GenerationState::Idle) => "Ready",
    };
    Paragraph::new(vec![
        Line::styled(
            "WORKFLOW",
            Style::default()
                .fg(Theme::VIOLET)
                .add_modifier(Modifier::BOLD),
        ),
        Line::raw(""),
        Line::styled("01  Context", Theme::muted()),
        Line::styled("02  Inspect", Theme::muted()),
        Line::styled("03  Answer", Theme::muted()),
        Line::raw(""),
        Line::styled(
            "SESSION",
            Style::default()
                .fg(Theme::VIOLET)
                .add_modifier(Modifier::BOLD),
        ),
        Line::styled(state, Style::default().fg(Theme::CYAN)),
        Line::raw(""),
        Line::styled(
            "FOCUS",
            Style::default()
                .fg(Theme::VIOLET)
                .add_modifier(Modifier::BOLD),
        ),
        Line::styled(focused, Theme::muted()),
    ])
    .block(Theme::panel("NAVIGATION"))
    .wrap(ratatui::widgets::Wrap { trim: true })
    .render(area, buffer);
}

fn render_footer(buffer: &mut ratatui::buffer::Buffer, area: Rect, model: &Model) {
    let message = model
        .rejection
        .as_ref()
        .map(|rejection| format!("Rejected: {}", rejection.reason))
        .unwrap_or_else(|| status_text(model));
    Paragraph::new(vec![
        Line::styled(message, Style::default().fg(Theme::MUTED)),
        Line::styled(
            "  ↑↓/jk Navigate  •  Enter Submit  •  Diagram: arrows/hjkl pan, +/- zoom, 0 reset  •  Esc Cancel  •  Ctrl-C Quit",
            Theme::muted(),
        ),
    ])
    .style(Style::default().bg(Theme::SURFACE))
    .render(area, buffer);
}

fn render_scrollbar(
    buffer: &mut ratatui::buffer::Buffer,
    area: Rect,
    model: &Model,
    tree: &crate::Template,
) {
    let document_height = crate::component_registry::content_height(tree, area.width.max(1));
    if document_height <= area.height || area.width == 0 || area.height == 0 {
        return;
    }
    let thumb_height = (u32::from(area.height) * u32::from(area.height)
        / u32::from(document_height))
    .max(1)
    .min(u32::from(area.height)) as u16;
    let range = document_height.saturating_sub(area.height).max(1);
    let thumb_range = area.height.saturating_sub(thumb_height);
    let thumb_offset =
        u32::from(model.viewport.scroll_y) * u32::from(thumb_range) / u32::from(range);
    for row in 0..area.height {
        let glyph = if row >= thumb_offset as u16 && row < thumb_offset as u16 + thumb_height {
            "┃"
        } else {
            "│"
        };
        buffer[(area.x + area.width - 1, area.y + row)]
            .set_symbol(glyph)
            .set_style(Style::default().fg(if glyph == "┃" {
                Theme::CYAN
            } else {
                Theme::BORDER
            }));
    }
}

fn workspace_title(profile: UiProfile) -> &'static str {
    match profile {
        UiProfile::Conversation => "WORKSPACE",
        UiProfile::Pr => "REVIEW WORKSPACE",
    }
}

fn humanize_id(id: &str) -> String {
    id.replace(['-', '_'], " ")
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
    use ratatui::{Terminal, backend::TestBackend, layout::Rect};

    use crate::{
        Button, FormField, Input, Template,
        application::{Effect, InputEvent, Message, Model, TerminalEvent, update},
        component_registry::{ComponentRegistry, Registry, RenderContext},
        protocol::{
            ComponentEvent, ProtocolVersion, ServerEnvelope, ServerMessage, SubmittedValue,
        },
    };

    use super::{UiProfile, shell_areas, status_text, terminal_message};

    #[test]
    fn pr_profile_uses_a_rail_only_when_the_terminal_is_large_enough() {
        assert!(
            shell_areas(Rect::new(0, 0, 120, 30), UiProfile::Pr)
                .rail
                .is_some()
        );
        assert!(
            shell_areas(Rect::new(0, 0, 80, 30), UiProfile::Pr)
                .rail
                .is_none()
        );
        assert!(
            shell_areas(Rect::new(0, 0, 120, 30), UiProfile::Conversation)
                .rail
                .is_none()
        );
    }

    #[test]
    fn profiles_are_parsed_from_the_launcher_values() {
        assert_eq!(
            UiProfile::parse("conversation"),
            Some(UiProfile::Conversation)
        );
        assert_eq!(UiProfile::parse("pr"), Some(UiProfile::Pr));
        assert_eq!(UiProfile::parse("other"), None);
    }

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
        let mut terminal = Terminal::new(TestBackend::new(24, 7)).expect("test terminal");

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
                        scroll_y: model.viewport.scroll_y,
                    },
                    frame.area(),
                    frame.buffer_mut(),
                );
            })
            .expect("rendered test terminal");

        assert_eq!(terminal.backend().buffer()[(1, 1)].symbol(), "A");
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
