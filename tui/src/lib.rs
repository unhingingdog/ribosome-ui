use serde::{Deserialize, Serialize};

pub mod application;
pub mod component_registry;
pub mod debug_log;
pub mod protocol;
pub mod runtime;
pub mod theme;
pub mod websocket;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase", deny_unknown_fields)]
pub enum Template {
    Text {
        id: String,
        text_type: TextType,
        #[serde(rename = "value")]
        content: String,
    },
    Image {
        id: String,
        src: String,
        alt: String,
    },
    Badge {
        id: String,
        label: String,
        variant: BadgeVariant,
    },
    List {
        id: String,
        #[serde(default)]
        ordered: Option<bool>,
        children: Vec<Template>,
    },
    Stat {
        id: String,
        label: String,
        value: String,
        #[serde(default)]
        secondary: Option<String>,
    },
    Divider {
        id: String,
        #[serde(default)]
        label: Option<String>,
    },
    Code {
        id: String,
        path: String,
        language: String,
        line_start: i64,
        source: String,
        highlights: Vec<CodeHighlight>,
    },
    Container {
        id: String,
        direction: Direction,
        children: Vec<Template>,
    },
    Submittable {
        id: String,
        #[serde(rename = "value")]
        fields: Vec<FormField>,
        #[serde(default)]
        button: Option<Button>,
    },
    Diagram {
        id: String,
        title: String,
        size: DiagramSize,
        primitives: Vec<DiagramPrimitive>,
    },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum BadgeVariant {
    Neutral,
    Success,
    Warning,
    Error,
    Info,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum CodeTone {
    Primary,
    Secondary,
    Success,
    Warning,
    Danger,
    Muted,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CodeHighlight {
    pub id: String,
    pub start_line: i64,
    pub end_line: i64,
    pub label: String,
    pub tone: CodeTone,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum DiagramSize {
    Compact,
    Regular,
    Tall,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum DiagramTone {
    Primary,
    Secondary,
    Success,
    Warning,
    Danger,
    Muted,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DiagramPoint {
    pub x: i16,
    pub y: i16,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "shape", rename_all = "lowercase", deny_unknown_fields)]
pub enum DiagramPrimitive {
    Text {
        id: String,
        at: DiagramPoint,
        value: String,
        tone: DiagramTone,
    },
    Line {
        id: String,
        #[serde(rename = "from")]
        from: DiagramPoint,
        to: DiagramPoint,
        tone: DiagramTone,
    },
    Arrow {
        id: String,
        #[serde(rename = "from")]
        from: DiagramPoint,
        to: DiagramPoint,
        tone: DiagramTone,
    },
    Rectangle {
        id: String,
        at: DiagramPoint,
        width: i16,
        height: i16,
        tone: DiagramTone,
    },
    Circle {
        id: String,
        at: DiagramPoint,
        radius: i16,
        tone: DiagramTone,
    },
    Polyline {
        id: String,
        #[serde(deserialize_with = "deserialize_polyline_points")]
        points: Vec<DiagramPoint>,
        tone: DiagramTone,
    },
}

fn deserialize_polyline_points<'de, D>(deserializer: D) -> Result<Vec<DiagramPoint>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let points = Vec::<DiagramPoint>::deserialize(deserializer)?;
    if points.len() < 2 {
        return Err(serde::de::Error::custom(
            "polyline requires at least two points",
        ));
    }
    Ok(points)
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum TextType {
    Paragraph,
    H1,
    H2,
    H3,
    H4,
    H5,
    H6,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Direction {
    Vertical,
    Horizontal,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum FormField {
    Input(Input),
    Select(Select),
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Input {
    pub id: String,
    #[serde(default)]
    pub value: Option<InputValue>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(untagged)]
pub enum InputValue {
    String(String),
    Integer(i64),
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Select {
    pub id: String,
    pub label: String,
    pub options: Vec<SelectOption>,
    #[serde(default)]
    pub selected: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SelectOption {
    pub value: String,
    pub label: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Button {
    pub kind: ButtonKind,
    pub id: String,
    pub label: String,
    pub action: String,
    #[serde(default)]
    pub disabled: Option<bool>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ButtonKind {
    Button,
}

#[cfg(test)]
mod tests {
    use super::{Direction, Template, TextType};

    #[test]
    fn parses_a_nested_form_tree() {
        let tree: Template = serde_json::from_str(
            r#"{"kind":"container","id":"root","direction":"vertical","children":[{"kind":"text","id":"title","text_type":"H1","value":"Review"},{"kind":"submittable","id":"quiz","value":[{"kind":"input","id":"answer","value":""}],"button":{"kind":"button","id":"submit","label":"Submit","action":"Submit"}}]}"#,
        )
        .expect("valid template");

        match tree {
            Template::Container {
                direction,
                children,
                ..
            } => {
                assert_eq!(direction, Direction::Vertical);
                match &children[0] {
                    Template::Text { text_type, .. } => assert_eq!(*text_type, TextType::H1),
                    Template::Container { .. }
                    | Template::Image { .. }
                    | Template::Badge { .. }
                    | Template::List { .. }
                    | Template::Stat { .. }
                    | Template::Divider { .. }
                    | Template::Code { .. }
                    | Template::Submittable { .. }
                    | Template::Diagram { .. } => {
                        panic!("expected text")
                    }
                }
            }
            Template::Text { .. }
            | Template::Image { .. }
            | Template::Badge { .. }
            | Template::List { .. }
            | Template::Stat { .. }
            | Template::Divider { .. }
            | Template::Code { .. }
            | Template::Submittable { .. }
            | Template::Diagram { .. } => {
                panic!("expected container")
            }
        }
    }

    #[test]
    fn rejects_a_container_without_direction() {
        let result =
            serde_json::from_str::<Template>(r#"{"kind":"container","id":"root","children":[]}"#);

        assert!(result.is_err());
    }

    #[test]
    fn rejects_unknown_template_kinds() {
        let result = serde_json::from_str::<Template>(r#"{"kind":"unknown","id":"status"}"#);

        assert!(result.is_err());
    }

    #[test]
    fn parses_the_existing_ribosome_leaf_templates() {
        let tree: Template = serde_json::from_str(
            r#"{"kind":"container","id":"root","direction":"vertical","children":[{"kind":"badge","id":"status","label":"Ready","variant":"Success"},{"kind":"stat","id":"score","label":"Score","value":"9"},{"kind":"divider","id":"boundary"},{"kind":"list","id":"items","children":[]},{"kind":"image","id":"preview","src":"https://example.com/preview.png","alt":"Preview"}]}"#,
        )
        .expect("supported Ribosome leaves");

        assert!(matches!(tree, Template::Container { .. }));
    }

    #[test]
    fn parses_a_highlighted_code_snippet() {
        let template: Template = serde_json::from_str(
            r#"{"kind":"code","id":"handler","path":"src/handler.rs","language":"rust","line_start":10,"source":"fn handle() {}","highlights":[{"id":"entry","start_line":10,"end_line":10,"label":"Entry point","tone":"primary"}]}"#,
        )
        .expect("valid code template");

        assert!(matches!(template, Template::Code { .. }));
    }

    #[test]
    fn parses_a_diagram_scene() {
        let template: Template = serde_json::from_str(
            r#"{"kind":"diagram","id":"flow","title":"Flow","size":"regular","primitives":[{"shape":"arrow","id":"request","from":{"x":10,"y":50},"to":{"x":90,"y":50},"tone":"secondary"},{"shape":"polyline","id":"return","points":[{"x":90,"y":60},{"x":50,"y":70}],"tone":"muted"}]}"#,
        )
        .expect("valid diagram");

        assert!(matches!(template, Template::Diagram { .. }));
    }

    #[test]
    fn rejects_a_single_point_polyline() {
        let result = serde_json::from_str::<Template>(
            r#"{"kind":"diagram","id":"flow","title":"Flow","size":"compact","primitives":[{"shape":"polyline","id":"line","points":[{"x":1,"y":2}],"tone":"primary"}]}"#,
        );

        assert!(result.is_err());
    }
}
