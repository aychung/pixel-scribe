import gleam/json
import gleam/string

pub const max_event_bytes = 8192

pub type EncodeError {
  FrameTooLarge
}

/// Encode a join for the only room supported by the MVP.
pub fn encode_join_room(username: String) -> Result(String, EncodeError) {
  json.object([
    #("type", json.string("join_room")),
    #("room_id", json.string("default")),
    #("username", json.string(username)),
  ])
  |> encode_bounded_frame
}

/// Encode a chat message for the only room supported by the MVP.
pub fn encode_send_message(text: String) -> Result(String, EncodeError) {
  json.object([
    #("type", json.string("send_message")),
    #("room_id", json.string("default")),
    #("text", json.string(text)),
  ])
  |> encode_bounded_frame
}

fn encode_bounded_frame(event: json.Json) -> Result(String, EncodeError) {
  let frame = json.to_string(event)
  let byte_count = string.byte_size(frame)

  case byte_count <= max_event_bytes {
    True -> Ok(frame)
    False -> Error(FrameTooLarge)
  }
}
