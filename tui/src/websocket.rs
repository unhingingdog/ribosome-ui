use std::{io::ErrorKind, net::TcpStream};

use tungstenite::{Message, WebSocket, stream::MaybeTlsStream};

use crate::{
    application::{Effect, Model},
    debug_log,
    protocol::{ClientEnvelope, ClientMessage, ProtocolVersion, ServerEnvelope},
};

pub struct DreamConnection {
    socket: WebSocket<MaybeTlsStream<TcpStream>>,
}

#[derive(Debug)]
pub enum TransportError {
    Websocket(Box<tungstenite::Error>),
    Json(serde_json::Error),
    MissingSession,
}

pub enum ReceiveResult {
    ServerMessage(ServerEnvelope),
    Disconnected,
    Pending,
    Ignored,
}

impl DreamConnection {
    pub fn connect(url: &str) -> Result<Self, Box<tungstenite::Error>> {
        tungstenite::connect(url)
            .map(|(socket, _)| Self { socket })
            .map_err(Box::new)
    }

    pub fn execute(
        &mut self,
        effect: Effect,
        model: &Model,
        event_id: String,
    ) -> Result<(), TransportError> {
        let message = client_message(effect, model, event_id)?;
        self.send(message)
    }

    pub fn send(&mut self, message: ClientEnvelope) -> Result<(), TransportError> {
        let encoded = serde_json::to_string(&message).map_err(TransportError::Json)?;
        debug_log::write("TUI -> DREAM", &encoded);

        self.socket
            .send(Message::Text(encoded))
            .map_err(|error| TransportError::Websocket(Box::new(error)))
    }

    pub fn set_nonblocking(&mut self, nonblocking: bool) -> Result<(), TransportError> {
        match self.socket.get_mut() {
            MaybeTlsStream::Plain(stream) => stream.set_nonblocking(nonblocking).map_err(|error| {
                TransportError::Websocket(Box::new(tungstenite::Error::Io(error)))
            }),
            _ => Ok(()),
        }
    }

    pub fn receive(&mut self) -> Result<ReceiveResult, TransportError> {
        match self
            .socket
            .read()
            .map_err(|error| TransportError::Websocket(Box::new(error)))?
        {
            Message::Text(message) => {
                debug_log::write("DREAM -> TUI", message.as_str());
                serde_json::from_str(message.as_str())
                    .map(ReceiveResult::ServerMessage)
                    .map_err(TransportError::Json)
            }
            Message::Close(_) => Ok(ReceiveResult::Disconnected),
            Message::Binary(_) | Message::Ping(_) | Message::Pong(_) | Message::Frame(_) => {
                Ok(ReceiveResult::Ignored)
            }
        }
    }

    pub fn try_receive(&mut self) -> Result<ReceiveResult, TransportError> {
        match self.receive() {
            Err(TransportError::Websocket(error)) if matches!(error.as_ref(), tungstenite::Error::Io(error) if error.kind() == ErrorKind::WouldBlock) => {
                Ok(ReceiveResult::Pending)
            }
            result => result,
        }
    }
}

pub fn client_message(
    effect: Effect,
    model: &Model,
    event_id: String,
) -> Result<ClientEnvelope, TransportError> {
    let session = model
        .session
        .as_ref()
        .ok_or(TransportError::MissingSession)?;
    let message = match effect {
        Effect::ComponentEvent(event) => ClientMessage::ComponentEvent {
            session_id: session.id.clone(),
            event_id,
            base_revision: session.revision,
            event,
        },
        Effect::CancelGeneration => ClientMessage::Cancel {
            session_id: session.id.clone(),
        },
    };

    Ok(ClientEnvelope {
        protocol_version: ProtocolVersion::V1,
        message,
    })
}

#[cfg(test)]
mod tests {
    use crate::{
        application::{Effect, Model, Session},
        protocol::{ClientMessage, ComponentEvent, ProtocolVersion},
    };

    use super::client_message;

    fn model() -> Model {
        Model {
            session: Some(Session {
                id: String::from("session-1"),
                revision: 4,
                tree: None,
            }),
            ..Model::default()
        }
    }

    #[test]
    fn component_effects_include_current_session_and_revision() {
        let message = client_message(
            Effect::ComponentEvent(ComponentEvent::Click {
                id: String::from("approve"),
            }),
            &model(),
            String::from("event-1"),
        )
        .expect("session is present");

        assert_eq!(message.protocol_version, ProtocolVersion::V1);
        assert_eq!(
            message.message,
            ClientMessage::ComponentEvent {
                session_id: String::from("session-1"),
                event_id: String::from("event-1"),
                base_revision: 4,
                event: ComponentEvent::Click {
                    id: String::from("approve"),
                },
            }
        );
    }

    #[test]
    fn cancellation_effects_target_the_current_session() {
        let message = client_message(Effect::CancelGeneration, &model(), String::new())
            .expect("session is present");

        assert_eq!(
            message.message,
            ClientMessage::Cancel {
                session_id: String::from("session-1"),
            }
        );
    }
}
