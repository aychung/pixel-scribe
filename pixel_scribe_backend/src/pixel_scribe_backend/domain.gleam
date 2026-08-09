import gleam/int
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp
import pixel_scribe_backend/validation

pub opaque type RoomId {
  RoomId(String)
}

pub opaque type Username {
  Username(String)
}

pub opaque type MessageText {
  MessageText(String)
}

pub opaque type ConnectionId {
  ConnectionId(String)
}

pub opaque type MessageId {
  MessageId(String)
}

pub opaque type SentAt {
  SentAt(timestamp.Timestamp)
}

pub type Presence {
  Presence(connection_id: ConnectionId, username: Username)
}

pub type ChatMessage {
  ChatMessage(
    message_id: MessageId,
    sender_id: ConnectionId,
    username: Username,
    text: MessageText,
    sent_at: SentAt,
  )
}

pub const default_room_id = RoomId("default")

pub fn new_room_id(raw: String) -> Result(RoomId, validation.RoomIdError) {
  raw
  |> validation.normalize_room_id
  |> result.map(RoomId)
}

pub fn new_username(raw: String) -> Result(Username, validation.UsernameError) {
  raw
  |> validation.normalize_username
  |> result.map(Username)
}

pub fn new_message_text(
  raw: String,
) -> Result(MessageText, validation.MessageTextError) {
  raw
  |> validation.normalize_message_text
  |> result.map(MessageText)
}

pub fn new_connection_id() -> ConnectionId {
  ConnectionId("connection-" <> int.to_string(unique_integer()))
}

pub fn new_message_id() -> MessageId {
  MessageId("message-" <> int.to_string(unique_integer()))
}

pub fn new_sent_at() -> SentAt {
  SentAt(timestamp.system_time())
}

pub fn room_id_to_string(room_id: RoomId) -> String {
  let RoomId(value) = room_id
  value
}

pub fn username_to_string(username: Username) -> String {
  let Username(value) = username
  value
}

pub fn message_text_to_string(text: MessageText) -> String {
  let MessageText(value) = text
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

pub fn sent_at_to_rfc3339(sent_at: SentAt) -> String {
  let SentAt(value) = sent_at
  timestamp.to_rfc3339(value, calendar.utc_offset)
}

@external(erlang, "erlang", "unique_integer")
fn unique_integer() -> Int
