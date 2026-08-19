use std::collections::BTreeMap;

use ratatui::{
    buffer::Buffer,
    layout::{Constraint, Direction as LayoutDirection, Layout, Rect},
    style::{Modifier, Style},
    widgets::{Paragraph, Widget},
};

use crate::{
    Button, Direction, FormField, Input, Select, Template,
    application::{FocusState, WidgetState},
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
}

#[derive(Clone, Copy, Debug, Default)]
pub struct Registry;

impl ComponentRegistry for Registry {
    fn render(
        &self,
        template: &Template,
        context: &RenderContext<'_>,
        area: Rect,
        buffer: &mut Buffer,
    ) {
        match template {
            Template::Text { content, .. } => Paragraph::new(content.as_str()).render(area, buffer),
            Template::Container {
                direction,
                children,
                ..
            } => render_container(self, direction, children, context, area, buffer),
            Template::Submittable { fields, button, .. } => {
                render_submittable(fields, button.as_ref(), context, area, buffer)
            }
        }
    }
}

fn render_container(
    registry: &Registry,
    direction: &Direction,
    children: &[Template],
    context: &RenderContext<'_>,
    area: Rect,
    buffer: &mut Buffer,
) {
    if children.is_empty() {
        return;
    }

    let direction = match direction {
        Direction::Vertical => LayoutDirection::Vertical,
        Direction::Horizontal => LayoutDirection::Horizontal,
    };
    let constraints = vec![Constraint::Ratio(1, children.len() as u32); children.len()];
    let areas = Layout::default()
        .direction(direction)
        .constraints(constraints)
        .split(area);

    for (child, child_area) in children.iter().zip(areas.iter()) {
        registry.render(child, context, *child_area, buffer);
    }
}

fn render_submittable(
    fields: &[FormField],
    button: Option<&Button>,
    context: &RenderContext<'_>,
    area: Rect,
    buffer: &mut Buffer,
) {
    let count = fields.len() + usize::from(button.is_some());
    if count == 0 {
        return;
    }

    let areas = Layout::default()
        .direction(LayoutDirection::Vertical)
        .constraints(vec![Constraint::Length(1); count])
        .split(area);
    for (field, field_area) in fields.iter().zip(areas.iter()) {
        match field {
            FormField::Input(input) => render_input(input, context, *field_area, buffer),
            FormField::Select(select) => render_select(select, context, *field_area, buffer),
        }
    }
    if let (Some(button), Some(button_area)) = (button, areas.last()) {
        render_button(button, context, *button_area, buffer);
    }
}

fn render_input(input: &Input, context: &RenderContext<'_>, area: Rect, buffer: &mut Buffer) {
    let (value, cursor) = match context.local.get(&input.id) {
        Some(WidgetState::Input { value, cursor }) => (value.as_str(), *cursor),
        Some(WidgetState::Select { .. }) | None => ("", 0),
    };
    InputWidget {
        value,
        cursor,
        focused: is_focused(context, &input.id),
    }
    .render(area, buffer);
}

fn render_select(select: &Select, context: &RenderContext<'_>, area: Rect, buffer: &mut Buffer) {
    let selected = match context.local.get(&select.id) {
        Some(WidgetState::Select { selected }) => selected.as_deref().unwrap_or(""),
        Some(WidgetState::Input { .. }) | None => "",
    };
    let marker = if is_focused(context, &select.id) {
        "> "
    } else {
        "  "
    };
    Paragraph::new(format!("{marker}{}: {selected}", select.label)).render(area, buffer);
}

fn render_button(button: &Button, context: &RenderContext<'_>, area: Rect, buffer: &mut Buffer) {
    let marker = if is_focused(context, &button.id) {
        "> "
    } else {
        "  "
    };
    let disabled = button.disabled.unwrap_or(false);
    let suffix = if disabled { " (disabled)" } else { "" };
    Paragraph::new(format!("{marker}[{}]{suffix}", button.label)).render(area, buffer);
}

fn is_focused(context: &RenderContext<'_>, id: &str) -> bool {
    matches!(context.focus, FocusState::Focused(focused) if focused == id)
}

struct InputWidget<'a> {
    value: &'a str,
    cursor: usize,
    focused: bool,
}

impl Widget for InputWidget<'_> {
    fn render(self, area: Rect, buffer: &mut Buffer) {
        let marker = if self.focused { "> " } else { "  " };
        Paragraph::new(format!("{marker}{}", self.value)).render(area, buffer);

        if self.focused && area.width > 0 {
            let cursor = self.cursor.min(self.value.chars().count());
            let x = area.x + (2 + cursor) as u16;
            if x < area.x + area.width {
                buffer[(x, area.y)].set_style(Style::default().add_modifier(Modifier::REVERSED));
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use ratatui::{buffer::Buffer, layout::Rect};

    use crate::{
        Button, Direction, FormField, Input, Template, TextType,
        application::{FocusState, WidgetState},
    };

    use super::{ComponentRegistry, Registry, RenderContext};

    #[test]
    fn text_templates_bind_to_paragraphs() {
        let mut buffer = Buffer::empty(Rect::new(0, 0, 8, 1));
        let template = Template::Text {
            id: String::from("title"),
            text_type: TextType::H1,
            content: String::from("Review"),
        };
        let local = BTreeMap::new();
        let context = RenderContext {
            local: &local,
            focus: &FocusState::None,
        };

        Registry.render(&template, &context, buffer.area, &mut buffer);

        assert_eq!(buffer[(0, 0)].symbol(), "R");
        assert_eq!(buffer[(5, 0)].symbol(), "w");
    }

    #[test]
    fn containers_render_children_in_their_layout_direction() {
        let mut buffer = Buffer::empty(Rect::new(0, 0, 4, 2));
        let template = Template::Container {
            id: String::from("root"),
            direction: Direction::Vertical,
            children: vec![
                Template::Text {
                    id: String::from("first"),
                    text_type: TextType::Paragraph,
                    content: String::from("A"),
                },
                Template::Text {
                    id: String::from("second"),
                    text_type: TextType::Paragraph,
                    content: String::from("B"),
                },
            ],
        };
        let local = BTreeMap::new();
        let context = RenderContext {
            local: &local,
            focus: &FocusState::None,
        };

        Registry.render(&template, &context, buffer.area, &mut buffer);

        assert_eq!(buffer[(0, 0)].symbol(), "A");
        assert_eq!(buffer[(0, 1)].symbol(), "B");
    }

    #[test]
    fn submittable_templates_render_custom_inputs_and_buttons() {
        let mut buffer = Buffer::empty(Rect::new(0, 0, 12, 2));
        let template = Template::Submittable {
            id: String::from("form"),
            fields: vec![FormField::Input(Input {
                id: String::from("answer"),
                value: None,
            })],
            button: Some(Button {
                id: String::from("submit"),
                label: String::from("Submit"),
                action: String::from("Submit"),
                disabled: None,
            }),
        };
        let local = BTreeMap::from([(
            String::from("answer"),
            WidgetState::Input {
                value: String::from("Alice"),
                cursor: 5,
            },
        )]);
        let context = RenderContext {
            local: &local,
            focus: &FocusState::Focused(String::from("answer")),
        };

        Registry.render(&template, &context, buffer.area, &mut buffer);

        assert_eq!(buffer[(0, 0)].symbol(), ">");
        assert_eq!(buffer[(2, 0)].symbol(), "A");
        assert_eq!(buffer[(2, 1)].symbol(), "[");
    }
}
