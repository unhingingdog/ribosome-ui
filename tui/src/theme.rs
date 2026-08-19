use ratatui::{
    style::{Color, Modifier, Style},
    widgets::{Block, BorderType, Borders},
};

#[derive(Clone, Copy, Debug)]
pub struct Theme;

impl Theme {
    pub const BACKGROUND: Color = Color::Rgb(18, 22, 28);
    pub const SURFACE: Color = Color::Rgb(27, 33, 42);
    pub const SURFACE_RAISED: Color = Color::Rgb(35, 43, 55);
    pub const FOREGROUND: Color = Color::Rgb(225, 231, 239);
    pub const MUTED: Color = Color::Rgb(142, 156, 173);
    pub const BORDER: Color = Color::Rgb(65, 78, 96);
    pub const CYAN: Color = Color::Rgb(67, 214, 239);
    pub const VIOLET: Color = Color::Rgb(177, 151, 252);
    pub const GREEN: Color = Color::Rgb(109, 212, 150);
    pub const AMBER: Color = Color::Rgb(244, 193, 85);
    pub const RED: Color = Color::Rgb(255, 112, 112);

    pub fn panel(title: impl Into<String>) -> Block<'static> {
        Block::default()
            .borders(Borders::ALL)
            .border_type(BorderType::Rounded)
            .border_style(Style::default().fg(Self::BORDER))
            .title(title.into())
            .style(Style::default().bg(Self::SURFACE).fg(Self::FOREGROUND))
    }

    pub fn focused_panel(title: impl Into<String>) -> Block<'static> {
        Self::panel(title).border_style(Style::default().fg(Self::CYAN))
    }

    pub fn title() -> Style {
        Style::default().fg(Self::CYAN).add_modifier(Modifier::BOLD)
    }

    pub fn heading() -> Style {
        Style::default()
            .fg(Self::FOREGROUND)
            .add_modifier(Modifier::BOLD)
    }

    pub fn muted() -> Style {
        Style::default().fg(Self::MUTED)
    }
}
