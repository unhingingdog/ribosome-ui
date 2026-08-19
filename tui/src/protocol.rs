use serde::{Deserialize, Deserializer, Serialize, Serializer};

use crate::{InputValue, Template};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ProtocolVersion {
    V1,
}

impl Serialize for ProtocolVersion {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_u8(1)
    }
}

impl<'de> Deserialize<'de> for ProtocolVersion {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        match u8::deserialize(deserializer)? {
            1 => Ok(Self::V1),
            _ => Err(serde::de::Error::custom("unsupported protocol version")),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClientEnvelope {
    #[serde(rename = "protocolVersion")]
    pub protocol_version: ProtocolVersion,
    #[serde(flatten)]
    pub message: ClientMessage,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    tag = "type",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
pub enum ClientMessage {
    NewSession {
        #[serde(deserialize_with = "deserialize_non_blank")]
        initial_prompt: String,
    },
    ResumeSession {
        session_id: String,
    },
    ComponentEvent {
        session_id: String,
        event_id: String,
        base_revision: i64,
        event: ComponentEvent,
    },
    Cancel {
        session_id: String,
    },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
pub enum ComponentEvent {
    Click {
        id: String,
    },
    Change {
        id: String,
        value: InputValue,
    },
    Submit {
        id: String,
        values: Vec<SubmittedValue>,
    },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SubmittedValue {
    pub id: String,
    pub value: InputValue,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServerEnvelope {
    #[serde(rename = "protocolVersion")]
    pub protocol_version: ProtocolVersion,
    #[serde(flatten)]
    pub message: ServerMessage,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    tag = "type",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
pub enum ServerMessage {
    SessionState {
        session_id: String,
        revision: i64,
        #[serde(skip_serializing_if = "Option::is_none")]
        tree: Option<Template>,
    },
    TemplateUpdate {
        session_id: String,
        revision: i64,
        tree: Template,
    },
    GenerationStarted {
        session_id: String,
        turn_id: String,
    },
    GenerationCompleted {
        session_id: String,
        turn_id: String,
    },
    GenerationFailed {
        session_id: String,
        turn_id: String,
        message: String,
    },
    EventRejected {
        session_id: String,
        event_id: String,
        reason: String,
    },
}

fn deserialize_non_blank<'de, D>(deserializer: D) -> Result<String, D::Error>
where
    D: Deserializer<'de>,
{
    let value = String::deserialize(deserializer)?;

    if value.trim().is_empty() {
        Err(serde::de::Error::custom("initialPrompt must not be blank"))
    } else {
        Ok(value)
    }
}

#[cfg(test)]
mod tests {
    use super::{ClientEnvelope, ProtocolVersion, ServerEnvelope};

    #[test]
    fn encodes_the_shared_client_fixture() {
        let expected = include_str!("../../protocol_fixtures/component-event.json");
        let message: ClientEnvelope = serde_json::from_str(expected).expect("valid client fixture");

        assert_eq!(
            serde_json::to_string(&message).expect("serializes"),
            expected.trim()
        );
    }

    #[test]
    fn decodes_the_shared_server_fixture() {
        let fixture = include_str!("../../protocol_fixtures/template-update.json");
        let message: ServerEnvelope = serde_json::from_str(fixture).expect("valid server fixture");

        assert_eq!(message.protocol_version, ProtocolVersion::V1);
    }

    #[test]
    fn rejects_blank_initial_prompts() {
        let result = serde_json::from_str::<ClientEnvelope>(
            r#"{"protocolVersion":1,"type":"newSession","initialPrompt":"  "}"#,
        );

        assert!(result.is_err());
    }

    #[test]
    fn rejects_other_protocol_versions() {
        let result = serde_json::from_str::<ClientEnvelope>(
            r#"{"protocolVersion":2,"type":"resumeSession","sessionId":"session-1"}"#,
        );

        assert!(result.is_err());
    }
}
