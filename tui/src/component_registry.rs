use std::collections::BTreeMap;

use ratatui::{
    buffer::Buffer,
    layout::{Constraint, Direction as LayoutDirection, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span, Text},
    widgets::{
        Paragraph, Widget, Wrap,
        canvas::{Canvas, Circle, Line as CanvasLine, Rectangle},
    },
};

use crate::{
    BadgeVariant, Button, CodeHighlight, CodeTone, DiagramPrimitive, DiagramSize, DiagramTone,
    Direction, FormField, Input, Select, Template, TextType,
    application::{FocusState, WidgetState},
    theme::Theme,
};

pub trait ComponentRegistry {
    fn render(
        &self,
        template: &Template,
        context: &RenderContext<'_>,
        area: Rect,
        buffer: &mut Buffer,
    );
}

pub struct RenderContext<'a> {
    pub local: &'a BTreeMap<String, WidgetState>,
    pub focus: &'a FocusState,
    pub scroll_y: u16,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Interaction {
    Focus(String),
    Activate(String),
}

#[derive(Clone, Copy, Debug, Default)]
pub struct Registry;

pub fn content_height(template: &Template, width: u16) -> u16 {
    match template {
        Template::Text {
            text_type, content, ..
        } => text_height(text_type.clone(), content, width),
        Template::Image { alt, src, .. } => {
            text_height(TextType::Paragraph, &format!("[image] {alt}\n{src}"), width)
        }
        Template::Badge { .. } | Template::Stat { .. } | Template::Divider { .. } => 1,
        Template::Code {
            source, highlights, ..
        } => code_height(source, highlights),
        Template::List { children, .. } => children
            .iter()
            .fold(0_u16, |height, child| {
                height
                    .saturating_add(content_height(child, width))
                    .saturating_add(1)
            })
            .saturating_sub(u16::from(!children.is_empty())),
        Template::Container {
            direction,
            children,
            ..
        } => match direction {
            Direction::Vertical => children
                .iter()
                .fold(0_u16, |height, child| {
                    height
                        .saturating_add(content_height(child, width))
                        .saturating_add(1)
                })
                .saturating_sub(u16::from(!children.is_empty())),
            Direction::Horizontal => {
                let count = u16::try_from(children.len()).unwrap_or(u16::MAX).max(1);
                let child_width = width.saturating_div(count).max(1);
                children
                    .iter()
                    .map(|child| content_height(child, child_width))
                    .max()
                    .unwrap_or(0)
            }
        },
        Template::Submittable { fields, button, .. } => {
            let controls = fields.len() + usize::from(button.is_some());
            let controls = u16::try_from(controls).unwrap_or(u16::MAX);
            controls
                .saturating_mul(4)
                .saturating_sub(u16::from(controls > 0))
        }
        Template::Diagram { size, .. } => diagram_height(size),
    }
}

pub fn interaction_at(
    template: &Template,
    area: Rect,
    scroll_y: u16,
    x: u16,
    y: u16,
) -> Option<Interaction> {
    let document_y = i32::from(area.y) - i32::from(scroll_y);
    interaction_at_document(template, area.x, area.width, document_y, area, x, y)
}

fn interaction_at_document(
    template: &Template,
    x: u16,
    width: u16,
    document_y: i32,
    viewport: Rect,
    target_x: u16,
    target_y: u16,
) -> Option<Interaction> {
    match template {
        Template::Text { .. }
        | Template::Image { .. }
        | Template::Badge { .. }
        | Template::Stat { .. }
        | Template::Divider { .. }
        | Template::Code { .. } => None,
        Template::Diagram { id, size, .. } => contains_document(
            x,
            width,
            document_y,
            diagram_height(size),
            viewport,
            target_x,
            target_y,
        )
        .then(|| Interaction::Focus(id.clone())),
        Template::List { children, .. } => {
            let mut child_y = document_y;
            for child in children {
                if let Some(interaction) =
                    interaction_at_document(child, x, width, child_y, viewport, target_x, target_y)
                {
                    return Some(interaction);
                }
                child_y += i32::from(content_height(child, width)) + 1;
            }
            None
        }
        Template::Container {
            direction,
            children,
            ..
        } => match direction {
            Direction::Vertical => {
                let mut child_y = document_y;
                for child in children {
                    if let Some(interaction) = interaction_at_document(
                        child, x, width, child_y, viewport, target_x, target_y,
                    ) {
                        return Some(interaction);
                    }
                    child_y += i32::from(content_height(child, width)) + 1;
                }
                None
            }
            Direction::Horizontal => {
                let areas = horizontal_areas(x, width, children.len(), document_y);
                children.iter().zip(areas).find_map(|(child, (x, width))| {
                    interaction_at_document(
                        child, x, width, document_y, viewport, target_x, target_y,
                    )
                })
            }
        },
        Template::Submittable { fields, button, .. } => {
            let mut control_y = document_y;
            for field in fields {
                if contains_document(x, width, control_y, 3, viewport, target_x, target_y) {
                    let id = match field {
                        FormField::Input(input) => &input.id,
                        FormField::Select(select) => &select.id,
                    };
                    return Some(Interaction::Focus(id.clone()));
                }
                control_y += 4;
            }
            match button {
                Some(button)
                    if contains_document(x, width, control_y, 3, viewport, target_x, target_y) =>
                {
                    Some(Interaction::Activate(button.id.clone()))
                }
                Some(_) | None => None,
            }
        }
    }
}

fn contains_document(
    x: u16,
    width: u16,
    document_y: i32,
    height: u16,
    viewport: Rect,
    target_x: u16,
    target_y: u16,
) -> bool {
    let top = document_y.max(i32::from(viewport.y));
    let bottom = (document_y + i32::from(height)).min(i32::from(viewport.y + viewport.height));
    target_x >= x
        && target_x < x + width
        && i32::from(target_y) >= top
        && i32::from(target_y) < bottom
}

fn horizontal_areas(x: u16, width: u16, count: usize, y: i32) -> Vec<(u16, u16)> {
    if count == 0 {
        return Vec::new();
    }
    Layout::default()
        .direction(LayoutDirection::Horizontal)
        .constraints(vec![Constraint::Ratio(1, count as u32); count])
        .split(Rect::new(x, 0, width, 1))
        .iter()
        .map(|area| (area.x, area.width))
        .collect::<Vec<_>>()
        .into_iter()
        .map(|(child_x, child_width)| {
            let _ = y;
            (child_x, child_width)
        })
        .collect()
}

impl ComponentRegistry for Registry {
    fn render(
        &self,
        template: &Template,
        context: &RenderContext<'_>,
        area: Rect,
        buffer: &mut Buffer,
    ) {
        let document_y = i32::from(area.y) - i32::from(context.scroll_y);
        render_document(
            template, context, area.x, area.width, document_y, area, buffer,
        );
    }
}

fn render_document(
    template: &Template,
    context: &RenderContext<'_>,
    x: u16,
    width: u16,
    document_y: i32,
    viewport: Rect,
    buffer: &mut Buffer,
) {
    match template {
        Template::Text {
            text_type, content, ..
        } => render_text(
            text_type.clone(),
            content,
            x,
            width,
            document_y,
            viewport,
            buffer,
        ),
        Template::Image { alt, src, .. } => render_text(
            TextType::Paragraph,
            &format!("[image] {alt}\n{src}"),
            x,
            width,
            document_y,
            viewport,
            buffer,
        ),
        Template::Badge { label, variant, .. } => render_leaf(
            &format!(" {label} "),
            badge_style(variant),
            x,
            width,
            document_y,
            viewport,
            buffer,
        ),
        Template::Stat {
            label,
            value,
            secondary,
            ..
        } => {
            let value = match secondary {
                Some(secondary) => format!("{label}: {value}  {secondary}"),
                None => format!("{label}: {value}"),
            };
            render_leaf(
                &value,
                Style::default()
                    .fg(Theme::CYAN)
                    .add_modifier(Modifier::BOLD),
                x,
                width,
                document_y,
                viewport,
                buffer,
            );
        }
        Template::Divider { label, .. } => render_leaf(
            &format!("──── {} ────", label.as_deref().unwrap_or("")),
            Theme::muted(),
            x,
            width,
            document_y,
            viewport,
            buffer,
        ),
        Template::Code { .. } => render_code(template, x, width, document_y, viewport, buffer),
        Template::List { children, .. } => {
            let mut child_y = document_y;
            for child in children {
                render_document(child, context, x, width, child_y, viewport, buffer);
                child_y += i32::from(content_height(child, width)) + 1;
            }
        }
        Template::Container {
            direction,
            children,
            ..
        } => match direction {
            Direction::Vertical => {
                let mut child_y = document_y;
                for child in children {
                    render_document(child, context, x, width, child_y, viewport, buffer);
                    child_y += i32::from(content_height(child, width)) + 1;
                }
            }
            Direction::Horizontal => {
                for (child, (child_x, child_width)) in
                    children
                        .iter()
                        .zip(horizontal_areas(x, width, children.len(), document_y))
                {
                    render_document(
                        child,
                        context,
                        child_x,
                        child_width,
                        document_y,
                        viewport,
                        buffer,
                    );
                }
            }
        },
        Template::Submittable { fields, button, .. } => render_submittable(
            fields,
            button.as_ref(),
            context,
            DocumentArea {
                x,
                width,
                document_y,
                viewport,
            },
            buffer,
        ),
        Template::Diagram {
            id,
            title,
            size,
            primitives,
        } => render_diagram(
            id,
            title,
            size,
            primitives,
            context,
            DocumentArea {
                x,
                width,
                document_y,
                viewport,
            },
            buffer,
        ),
    }
}

fn code_height(source: &str, highlights: &[CodeHighlight]) -> u16 {
    let source_lines = u16::try_from(source.lines().count().max(1)).unwrap_or(u16::MAX);
    let labels = u16::try_from(highlights.len()).unwrap_or(u16::MAX);
    source_lines.saturating_add(labels).saturating_add(2)
}

fn render_code(
    template: &Template,
    x: u16,
    width: u16,
    document_y: i32,
    viewport: Rect,
    buffer: &mut Buffer,
) {
    let Template::Code {
        path,
        language,
        line_start,
        source,
        highlights,
        ..
    } = template
    else {
        return;
    };
    let height = code_height(source, highlights);
    let Some((area, skipped_rows)) = visible_area(x, width, document_y, height, viewport) else {
        return;
    };
    let line_count = source.lines().count().max(1);
    let last_line = *line_start + i64::try_from(line_count.saturating_sub(1)).unwrap_or(i64::MAX);
    let line_number_width = last_line.to_string().len();
    let rows = code_rows(
        path,
        language,
        *line_start,
        source,
        highlights,
        line_number_width,
        usize::from(width),
    );
    for (row, (content, style)) in rows
        .into_iter()
        .skip(usize::from(skipped_rows))
        .take(usize::from(area.height))
        .enumerate()
    {
        Paragraph::new(content).style(style).render(
            Rect::new(
                area.x,
                area.y + u16::try_from(row).unwrap_or(u16::MAX),
                area.width,
                1,
            ),
            buffer,
        );
    }
}

fn code_rows(
    path: &str,
    language: &str,
    line_start: i64,
    source: &str,
    highlights: &[CodeHighlight],
    line_number_width: usize,
    width: usize,
) -> Vec<(String, Style)> {
    let mut rows = vec![(
        clip_code_line(&format!("╭─ {path} · {language}"), width),
        Theme::heading(),
    )];
    let lines = source.lines().collect::<Vec<_>>();
    let lines = if lines.is_empty() { vec![""] } else { lines };
    for (index, source_line) in lines.into_iter().enumerate() {
        let number = line_start + i64::try_from(index).unwrap_or(i64::MAX);
        for highlight in highlights
            .iter()
            .filter(|highlight| highlight.start_line == number)
        {
            rows.push((
                clip_code_line(&format!("│  ↳ {}", highlight.label), width),
                Style::default()
                    .fg(code_tone_color(&highlight.tone))
                    .add_modifier(Modifier::BOLD),
            ));
        }
        let style = highlights
            .iter()
            .find(|highlight| number >= highlight.start_line && number <= highlight.end_line)
            .map(|highlight| {
                Style::default()
                    .fg(code_tone_color(&highlight.tone))
                    .bg(Theme::SURFACE_RAISED)
            })
            .unwrap_or_else(|| Style::default().fg(Theme::FOREGROUND));
        rows.push((
            clip_code_line(
                &format!("│ {:>line_number_width$} │ {source_line}", number),
                width,
            ),
            style,
        ));
    }
    rows.push((clip_code_line("╰─", width), Theme::muted()));
    rows
}

fn clip_code_line(value: &str, width: usize) -> String {
    if width == 0 {
        return String::new();
    }
    let count = value.chars().count();
    if count <= width {
        return value.to_owned();
    }
    let visible = width.saturating_sub(1);
    format!("{}…", value.chars().take(visible).collect::<String>())
}

fn code_tone_color(tone: &CodeTone) -> Color {
    match tone {
        CodeTone::Primary => Theme::CYAN,
        CodeTone::Secondary => Theme::VIOLET,
        CodeTone::Success => Theme::GREEN,
        CodeTone::Warning => Theme::AMBER,
        CodeTone::Danger => Theme::RED,
        CodeTone::Muted => Theme::MUTED,
    }
}

fn render_leaf(
    value: &str,
    style: Style,
    x: u16,
    width: u16,
    document_y: i32,
    viewport: Rect,
    buffer: &mut Buffer,
) {
    let Some((area, _)) = visible_area(x, width, document_y, 1, viewport) else {
        return;
    };
    Paragraph::new(value.to_owned())
        .style(style)
        .render(area, buffer);
}

fn badge_style(variant: &BadgeVariant) -> Style {
    let color = match variant {
        BadgeVariant::Neutral => Theme::MUTED,
        BadgeVariant::Success => Theme::GREEN,
        BadgeVariant::Warning => Theme::AMBER,
        BadgeVariant::Error => Theme::RED,
        BadgeVariant::Info => Theme::CYAN,
    };
    Style::default()
        .fg(Theme::BACKGROUND)
        .bg(color)
        .add_modifier(Modifier::BOLD)
}

fn render_text(
    text_type: TextType,
    content: &str,
    x: u16,
    width: u16,
    document_y: i32,
    viewport: Rect,
    buffer: &mut Buffer,
) {
    let height = text_height(text_type.clone(), content, width);
    let Some((area, skipped_rows)) = visible_area(x, width, document_y, height, viewport) else {
        return;
    };
    let paragraph = Paragraph::new(markdown_text(content))
        .style(text_style(text_type))
        .wrap(Wrap { trim: false })
        .scroll((skipped_rows, 0));
    paragraph.render(area, buffer);
}

struct DocumentArea {
    x: u16,
    width: u16,
    document_y: i32,
    viewport: Rect,
}

fn render_submittable(
    fields: &[FormField],
    button: Option<&Button>,
    context: &RenderContext<'_>,
    area: DocumentArea,
    buffer: &mut Buffer,
) {
    let mut control_y = area.document_y;
    for field in fields {
        if let Some((area, _)) = visible_area(area.x, area.width, control_y, 3, area.viewport) {
            match field {
                FormField::Input(input) => render_input(input, context, area, buffer),
                FormField::Select(select) => render_select(select, context, area, buffer),
            }
        }
        control_y += 4;
    }
    if let Some(button) = button
        && let Some((area, _)) = visible_area(area.x, area.width, control_y, 3, area.viewport)
    {
        render_button(button, context, area, buffer);
    }
}

fn diagram_height(size: &DiagramSize) -> u16 {
    match size {
        DiagramSize::Compact => 12,
        DiagramSize::Regular => 20,
        DiagramSize::Tall => 30,
    }
}

fn render_diagram(
    id: &str,
    title: &str,
    size: &DiagramSize,
    primitives: &[DiagramPrimitive],
    context: &RenderContext<'_>,
    area: DocumentArea,
    buffer: &mut Buffer,
) {
    let height = diagram_height(size);
    let Some((visible, skipped_rows)) =
        visible_area(area.x, area.width, area.document_y, height, area.viewport)
    else {
        return;
    };
    let mut offscreen = Buffer::empty(Rect::new(0, 0, area.width, height));
    let focused = is_focused(context, id);
    let block = if focused {
        Theme::focused_panel(title)
    } else {
        Theme::panel(title)
    };
    let inner = block.inner(offscreen.area);
    block.render(offscreen.area, &mut offscreen);
    let (center_x, center_y, zoom_percent) = match context.local.get(id) {
        Some(WidgetState::Diagram {
            center_x,
            center_y,
            zoom_percent,
        }) => (*center_x, *center_y, *zoom_percent),
        Some(WidgetState::Input { .. }) | Some(WidgetState::Select { .. }) | None => (50, 50, 100),
    };
    let span = 100.0 * 100.0 / f64::from(zoom_percent);
    let x_center = f64::from(center_x);
    let y_center = 100.0 - f64::from(center_y);
    Canvas::default()
        .x_bounds([x_center - span / 2.0, x_center + span / 2.0])
        .y_bounds([y_center - span / 2.0, y_center + span / 2.0])
        .marker(ratatui::symbols::Marker::HalfBlock)
        .paint(|canvas| {
            for primitive in primitives {
                draw_primitive(canvas, primitive);
            }
        })
        .render(inner, &mut offscreen);
    copy_visible_rows(&offscreen, buffer, visible, skipped_rows);
}

fn copy_visible_rows(source: &Buffer, target: &mut Buffer, target_area: Rect, source_y: u16) {
    for row in 0..target_area.height {
        for column in 0..target_area.width {
            target[(target_area.x + column, target_area.y + row)]
                .clone_from(&source[(column, source_y + row)]);
        }
    }
}

fn draw_primitive(
    canvas: &mut ratatui::widgets::canvas::Context<'_>,
    primitive: &DiagramPrimitive,
) {
    match primitive {
        DiagramPrimitive::Text {
            at, value, tone, ..
        } => canvas.print(
            f64::from(at.x),
            inverted_y(at.y),
            Line::styled(value.clone(), Style::default().fg(tone_color(tone))),
        ),
        DiagramPrimitive::Line { from, to, tone, .. } => canvas.draw(&CanvasLine::new(
            f64::from(from.x),
            inverted_y(from.y),
            f64::from(to.x),
            inverted_y(to.y),
            tone_color(tone),
        )),
        DiagramPrimitive::Arrow { from, to, tone, .. } => draw_arrow(canvas, from, to, tone),
        DiagramPrimitive::Rectangle {
            at,
            width,
            height,
            tone,
            ..
        } => canvas.draw(&Rectangle {
            x: f64::from(at.x),
            y: inverted_y(at.y + height),
            width: f64::from(*width),
            height: f64::from(*height),
            color: tone_color(tone),
        }),
        DiagramPrimitive::Circle {
            at, radius, tone, ..
        } => canvas.draw(&Circle {
            x: f64::from(at.x),
            y: inverted_y(at.y),
            radius: f64::from(*radius),
            color: tone_color(tone),
        }),
        DiagramPrimitive::Polyline { points, tone, .. } => {
            for pair in points.windows(2) {
                canvas.draw(&CanvasLine::new(
                    f64::from(pair[0].x),
                    inverted_y(pair[0].y),
                    f64::from(pair[1].x),
                    inverted_y(pair[1].y),
                    tone_color(tone),
                ));
            }
        }
    }
}

fn draw_arrow(
    canvas: &mut ratatui::widgets::canvas::Context<'_>,
    from: &crate::DiagramPoint,
    to: &crate::DiagramPoint,
    tone: &DiagramTone,
) {
    let color = tone_color(tone);
    let (x1, y1) = (f64::from(from.x), inverted_y(from.y));
    let (x2, y2) = (f64::from(to.x), inverted_y(to.y));
    canvas.draw(&CanvasLine::new(x1, y1, x2, y2, color));
    let angle = (y2 - y1).atan2(x2 - x1);
    for offset in [2.5_f64, -2.5_f64] {
        let tip_x = x2 - 4.0 * (angle + offset).cos();
        let tip_y = y2 - 4.0 * (angle + offset).sin();
        canvas.draw(&CanvasLine::new(x2, y2, tip_x, tip_y, color));
    }
}

fn inverted_y(y: i16) -> f64 {
    f64::from(100 - y)
}

fn tone_color(tone: &DiagramTone) -> Color {
    match tone {
        DiagramTone::Primary => Theme::CYAN,
        DiagramTone::Secondary => Theme::VIOLET,
        DiagramTone::Success => Theme::GREEN,
        DiagramTone::Warning => Theme::AMBER,
        DiagramTone::Danger => Theme::RED,
        DiagramTone::Muted => Theme::MUTED,
    }
}

fn visible_area(
    x: u16,
    width: u16,
    document_y: i32,
    height: u16,
    viewport: Rect,
) -> Option<(Rect, u16)> {
    let viewport_top = i32::from(viewport.y);
    let viewport_bottom = viewport_top + i32::from(viewport.height);
    let document_bottom = document_y + i32::from(height);
    if document_bottom <= viewport_top || document_y >= viewport_bottom {
        return None;
    }
    let top = document_y.max(viewport_top);
    let bottom = document_bottom.min(viewport_bottom);
    Some((
        Rect::new(x, top as u16, width, (bottom - top) as u16),
        (top - document_y) as u16,
    ))
}

fn render_input(input: &Input, context: &RenderContext<'_>, area: Rect, buffer: &mut Buffer) {
    let (value, cursor) = match context.local.get(&input.id) {
        Some(WidgetState::Input { value, cursor }) => (value.as_str(), *cursor),
        Some(WidgetState::Select { .. }) | Some(WidgetState::Diagram { .. }) | None => ("", 0),
    };
    let focused = is_focused(context, &input.id);
    let block = if focused {
        Theme::focused_panel(humanize_id(&input.id))
    } else {
        Theme::panel(humanize_id(&input.id))
    };
    let inner = block.inner(area);
    block.render(area, buffer);
    Paragraph::new(if value.is_empty() {
        "Type a response…"
    } else {
        value
    })
    .style(if value.is_empty() {
        Theme::muted()
    } else {
        Style::default().fg(Theme::FOREGROUND)
    })
    .render(inner, buffer);
    if focused && inner.width > 0 && inner.height > 0 {
        let cursor = cursor.min(value.chars().count());
        let cursor_x = inner.x + cursor.min(usize::from(inner.width.saturating_sub(1))) as u16;
        buffer[(cursor_x, inner.y)].set_style(
            Style::default()
                .fg(Theme::BACKGROUND)
                .bg(Theme::CYAN)
                .add_modifier(Modifier::BOLD),
        );
    }
}

fn render_select(select: &Select, context: &RenderContext<'_>, area: Rect, buffer: &mut Buffer) {
    let selected = match context.local.get(&select.id) {
        Some(WidgetState::Select { selected }) => selected.as_deref().unwrap_or("Select an option"),
        Some(WidgetState::Input { .. }) | Some(WidgetState::Diagram { .. }) | None => {
            "Select an option"
        }
    };
    let focused = is_focused(context, &select.id);
    let block = if focused {
        Theme::focused_panel(&select.label)
    } else {
        Theme::panel(&select.label)
    };
    let inner = block.inner(area);
    block.render(area, buffer);
    Paragraph::new(format!("‹ {selected} ›"))
        .style(Style::default().fg(if focused {
            Theme::CYAN
        } else {
            Theme::FOREGROUND
        }))
        .render(inner, buffer);
}

fn render_button(button: &Button, context: &RenderContext<'_>, area: Rect, buffer: &mut Buffer) {
    let disabled = button.disabled.unwrap_or(false);
    let focused = is_focused(context, &button.id);
    let style = if disabled {
        Style::default().bg(Theme::SURFACE_RAISED).fg(Theme::MUTED)
    } else if focused {
        Style::default()
            .bg(Theme::CYAN)
            .fg(Theme::BACKGROUND)
            .add_modifier(Modifier::BOLD)
    } else {
        Style::default()
            .bg(Theme::VIOLET)
            .fg(Theme::BACKGROUND)
            .add_modifier(Modifier::BOLD)
    };
    Paragraph::new(format!("  {}  ", button.label))
        .style(style)
        .centered()
        .render(area, buffer);
}

fn markdown_text(content: &str) -> Text<'static> {
    let mut in_code = false;
    let lines = content
        .lines()
        .map(|line| {
            if line.trim_start().starts_with("```") {
                in_code = !in_code;
                return Line::styled(line.to_owned(), Style::default().fg(Theme::VIOLET));
            }
            if in_code {
                return Line::styled(format!("  {line}"), Style::default().fg(Theme::CYAN));
            }
            if let Some(quote) = line.strip_prefix("> ") {
                return Line::styled(format!("│ {quote}"), Theme::muted());
            }
            if let Some(item) = line.strip_prefix("- ") {
                return Line::from(vec![
                    Span::styled("• ", Style::default().fg(Theme::CYAN)),
                    Span::raw(item.to_owned()),
                ]);
            }
            inline_code_line(line)
        })
        .collect::<Vec<_>>();
    let fallback = if lines.is_empty() {
        vec![Line::raw("")]
    } else {
        lines
    };
    Text::from(fallback)
}

fn inline_code_line(line: &str) -> Line<'static> {
    let mut spans = Vec::new();
    let mut code = false;
    for part in line.split('`') {
        let style = if code {
            Style::default().fg(Theme::AMBER).bg(Theme::SURFACE_RAISED)
        } else {
            Style::default().fg(Theme::FOREGROUND)
        };
        spans.push(Span::styled(part.to_owned(), style));
        code = !code;
    }
    Line::from(spans)
}

fn text_height(text_type: TextType, content: &str, width: u16) -> u16 {
    let width = usize::from(width.max(1));
    let line_count = content
        .lines()
        .map(|line| {
            let length = line.chars().count().max(1);
            u16::try_from(length.div_ceil(width)).unwrap_or(u16::MAX)
        })
        .sum::<u16>()
        .max(1);
    match text_type {
        TextType::H1 => line_count.saturating_add(2),
        TextType::H2 | TextType::H3 => line_count.saturating_add(1),
        TextType::H4 | TextType::H5 | TextType::H6 | TextType::Paragraph => line_count,
    }
}

fn text_style(text_type: TextType) -> Style {
    match text_type {
        TextType::H1 => Theme::title(),
        TextType::H2 | TextType::H3 => Theme::heading().fg(Theme::VIOLET),
        TextType::H4 | TextType::H5 | TextType::H6 => Theme::heading(),
        TextType::Paragraph => Style::default().fg(Theme::FOREGROUND),
    }
}

fn humanize_id(id: &str) -> String {
    id.split(['-', '_'])
        .filter(|part| !part.is_empty())
        .map(|part| {
            let mut characters = part.chars();
            match characters.next() {
                Some(first) => first.to_uppercase().collect::<String>() + characters.as_str(),
                None => String::new(),
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

fn is_focused(context: &RenderContext<'_>, id: &str) -> bool {
    matches!(context.focus, FocusState::Focused(focused) if focused == id)
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use ratatui::{buffer::Buffer, layout::Rect};

    use crate::{
        Button, ButtonKind, FormField, Input, Template, TextType,
        application::{FocusState, WidgetState},
    };

    use super::{
        ComponentRegistry, Interaction, Registry, RenderContext, content_height, interaction_at,
    };

    #[test]
    fn forms_have_intrinsic_height_instead_of_equal_container_ratios() {
        let template = Template::Submittable {
            id: String::from("form"),
            fields: vec![FormField::Input(Input {
                id: String::from("answer"),
                value: None,
            })],
            button: Some(Button {
                kind: ButtonKind::Button,
                id: String::from("continue"),
                label: String::from("Continue"),
                action: String::from("Submit"),
                disabled: None,
            }),
        };

        assert_eq!(content_height(&template, 40), 7);
    }

    #[test]
    fn form_mouse_targets_follow_document_scroll() {
        let template = Template::Container {
            id: String::from("root"),
            direction: crate::Direction::Vertical,
            children: vec![
                Template::Text {
                    id: String::from("intro"),
                    text_type: TextType::Paragraph,
                    content: "one\ntwo\nthree\nfour".to_owned(),
                },
                Template::Submittable {
                    id: String::from("form"),
                    fields: vec![FormField::Input(Input {
                        id: String::from("answer"),
                        value: None,
                    })],
                    button: None,
                },
            ],
        };

        assert_eq!(
            interaction_at(&template, Rect::new(0, 0, 30, 4), 5, 2, 0),
            Some(Interaction::Focus(String::from("answer")))
        );
    }

    #[test]
    fn custom_input_uses_a_focused_rounded_field() {
        let template = Template::Submittable {
            id: String::from("form"),
            fields: vec![FormField::Input(Input {
                id: String::from("answer"),
                value: None,
            })],
            button: None,
        };
        let local = BTreeMap::from([(
            String::from("answer"),
            WidgetState::Input {
                value: String::from("Hello"),
                cursor: 5,
            },
        )]);
        let mut buffer = Buffer::empty(Rect::new(0, 0, 24, 3));

        Registry.render(
            &template,
            &RenderContext {
                local: &local,
                focus: &FocusState::Focused(String::from("answer")),
                scroll_y: 0,
            },
            buffer.area,
            &mut buffer,
        );

        assert_eq!(buffer[(0, 0)].symbol(), "╭");
        assert_eq!(buffer[(1, 1)].symbol(), "H");
    }

    #[test]
    fn diagrams_have_named_height_and_are_focusable() {
        let diagram = Template::Diagram {
            id: String::from("flow"),
            title: String::from("Flow"),
            size: crate::DiagramSize::Regular,
            primitives: Vec::new(),
        };

        assert_eq!(content_height(&diagram, 40), 20);
        assert_eq!(
            interaction_at(&diagram, Rect::new(0, 0, 40, 20), 0, 2, 2),
            Some(Interaction::Focus(String::from("flow")))
        );
    }

    #[test]
    fn code_view_renders_line_numbers_and_highlight_labels() {
        let template: Template = serde_json::from_str(
            r#"{"kind":"code","id":"handler","path":"src/handler.rs","language":"rust","line_start":10,"source":"fn handle() {\n  dispatch();\n}","highlights":[{"id":"dispatch","start_line":11,"end_line":11,"label":"Dispatches the event","tone":"primary"}]}"#,
        )
        .expect("valid code template");
        let local = BTreeMap::new();
        let mut buffer = Buffer::empty(Rect::new(0, 0, 50, 6));

        Registry.render(
            &template,
            &RenderContext {
                local: &local,
                focus: &FocusState::None,
                scroll_y: 0,
            },
            buffer.area,
            &mut buffer,
        );

        assert_eq!(buffer[(3, 0)].symbol(), "s");
        assert_eq!(buffer[(5, 2)].symbol(), "D");
        assert_eq!(buffer[(2, 3)].symbol(), "1");
    }
}
