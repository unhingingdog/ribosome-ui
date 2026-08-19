use serde::{Deserialize, Serialize};

pub mod application;
pub mod component_registry;
pub mod protocol;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase", deny_unknown_fields)]
pub enum Template {
    Text {
        id: String,
        text_type: TextType,
        #[serde(rename = "value")]
        content: String,
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
    pub id: String,
    pub label: String,
    pub action: String,
    #[serde(default)]
    pub disabled: Option<bool>,
}

#[cfg(test)]
mod tests {
    use super::{Direction, Template, TextType};

    #[test]
    fn parses_a_nested_form_tree() {
        let tree: Template = serde_json::from_str(
            r#"{"kind":"container","id":"root","direction":"vertical","children":[{"kind":"text","id":"title","text_type":"H1","value":"Review"},{"kind":"submittable","id":"quiz","value":[{"kind":"input","id":"answer","value":""}],"button":{"id":"submit","label":"Submit","action":"Submit"}}]}"#,
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
                    Template::Container { .. } | Template::Submittable { .. } => {
                        panic!("expected text")
                    }
                }
            }
            Template::Text { .. } | Template::Submittable { .. } => panic!("expected container"),
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
        let result = serde_json::from_str::<Template>(r#"{"kind":"badge","id":"status"}"#);

        assert!(result.is_err());
    }
}
