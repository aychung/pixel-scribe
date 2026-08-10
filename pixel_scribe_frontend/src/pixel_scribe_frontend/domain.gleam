import gleam/option.{type Option}

/// An opaque room identifier carried by the wire protocol.
pub opaque type RoomId {
  RoomId(String)
}

/// An opaque server-issued connection identifier.
pub opaque type ConnectionId {
  ConnectionId(String)
}

/// An opaque server-issued chat message identifier.
pub opaque type MessageId {
  MessageId(String)
}

pub type Presence {
  Presence(connection_id: ConnectionId, username: String)
}

pub type ChatMessage {
  ChatMessage(
    message_id: MessageId,
    sender_id: ConnectionId,
    username: String,
    text: String,
    sent_at: String,
  )
}

/// The only room supported by the MVP.
pub const default_room_id = RoomId("default")

/// Wrap a room identifier received from a validated protocol boundary.
pub fn room_id_from_string(raw: String) -> RoomId {
  RoomId(raw)
}

/// Wrap a connection identifier received from a validated protocol boundary.
pub fn connection_id_from_string(raw: String) -> ConnectionId {
  ConnectionId(raw)
}

/// Wrap a message identifier received from a validated protocol boundary.
pub fn message_id_from_string(raw: String) -> MessageId {
  MessageId(raw)
}

pub fn room_id_to_string(room_id: RoomId) -> String {
  let RoomId(value) = room_id
  value
}

pub fn connection_id_to_string(connection_id: ConnectionId) -> String {
  let ConnectionId(value) = connection_id
  value
}

pub fn message_id_to_string(message_id: MessageId) -> String {
  let MessageId(value) = message_id
  value
}

/// Stable server error codes documented by the WebSocket contract.
pub type ErrorCode {
  /// Malformed JSON, an unknown client event, or an invalid event shape.
  InvalidEvent
  /// A room-scoped client event arrived before joining.
  JoinRequired
  /// A second join was attempted on one connection.
  AlreadyJoined
  /// The requested room identifier failed shape validation.
  InvalidRoomId
  /// The room identifier is valid but unsupported by the server.
  RoomNotFound
  /// An event's room does not match the joined room.
  RoomMismatch
  /// The joined room process is unavailable and the client must reconnect.
  RoomUnavailable
  /// The display username failed validation.
  InvalidUsername
  /// The chat message failed validation.
  InvalidMessage
  /// The connection exceeded the chat rate limit.
  RateLimited
  /// The room has reached its presence capacity.
  RoomFull
}

pub type ErrorEvent {
  ErrorEvent(
    room_id: Option(RoomId),
    code: ErrorCode,
    message: String,
    recoverable: Bool,
  )
}

pub type ServerEvent {
  RoomState(
    room_id: RoomId,
    self_id: ConnectionId,
    users: List(Presence),
    messages: List(ChatMessage),
  )
  UserJoined(room_id: RoomId, user: Presence)
  UserLeft(room_id: RoomId, connection_id: ConnectionId)
  MessageSent(room_id: RoomId, message: ChatMessage)
  ServerError(error: ErrorEvent)
  /// A future server event whose payload is intentionally discarded.
  UnknownEvent
}

/// A known server event that cannot become a trusted domain value.
///
/// This variant carries no raw payload so malformed input cannot leak into
/// application-visible error state or logs. Unknown future event types are
/// represented by `UnknownEvent` instead of this failure.
pub type DecodeError {
  MalformedServerEvent
}
