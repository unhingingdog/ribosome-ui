use crate::protocol::ServerEnvelope;

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Model;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Message {
    Server(ServerEnvelope),
    Terminal(TerminalEvent),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TerminalEvent;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Effect {}

pub fn update(message: Message, model: Model) -> (Model, Vec<Effect>) {
    match message {
        Message::Server(_) | Message::Terminal(_) => (model, Vec::new()),
    }
}

#[cfg(test)]
mod tests {
    use crate::protocol::{ProtocolVersion, ServerEnvelope, ServerMessage};

    use super::{Message, Model, TerminalEvent, update};

    #[test]
    fn server_messages_are_reduced_purely() {
        let model = Model;
        let message = Message::Server(ServerEnvelope {
            protocol_version: ProtocolVersion::V1,
            message: ServerMessage::GenerationStarted {
                session_id: String::from("session-1"),
                turn_id: String::from("turn-1"),
            },
        });

        let (next_model, effects) = update(message, model.clone());

        assert_eq!(next_model, model);
        assert!(effects.is_empty());
    }

    #[test]
    fn terminal_events_are_reduced_purely() {
        let model = Model;
        let (next_model, effects) = update(Message::Terminal(TerminalEvent), model.clone());

        assert_eq!(next_model, model);
        assert!(effects.is_empty());
    }
}
