import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/validation

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

/// Decode one server text frame into trusted protocol values.
///
/// Parser and validation details are deliberately collapsed into the single
/// payload-free domain error so untrusted frames cannot escape the boundary.
pub fn decode_server_event(
  payload: String,
) -> Result(domain.ServerEvent, domain.DecodeError) {
  case json.parse(from: payload, using: raw_server_event_decoder()) {
    Error(_) -> Error(domain.MalformedServerEvent)
    Ok(event) ->
      event
      |> trusted_server_event
      |> result.map_error(fn(_) { domain.MalformedServerEvent })
  }
}

type RawServerEvent {
  RawRoomState(
    room_id: String,
    self_id: String,
    users: List(RawPresence),
    messages: List(RawMessage),
  )
  RawUserJoined(room_id: String, user: RawPresence)
  RawUserLeft(room_id: String, connection_id: String)
  RawMessageSent(room_id: String, message: RawMessage)
  RawError(
    room_id: Option(String),
    code: String,
    message: String,
    recoverable: Bool,
  )
  RawUnknown
}

type RawPresence {
  RawPresence(connection_id: String, username: String)
}

type RawMessage {
  RawMessage(
    message_id: String,
    sender_id: String,
    username: String,
    text: String,
    sent_at: String,
  )
}

fn raw_server_event_decoder() -> decode.Decoder(RawServerEvent) {
  use event_type <- decode.field("type", decode.string)

  case event_type {
    "room_state" -> {
      use room_id <- decode.field("room_id", decode.string)
      use self_id <- decode.field("self_id", decode.string)
      use users <- decode.field(
        "users",
        decode.list(of: raw_presence_decoder()),
      )
      use messages <- decode.field(
        "messages",
        decode.list(of: raw_message_decoder()),
      )
      decode.success(RawRoomState(room_id, self_id, users, messages))
    }
    "user_joined" -> {
      use room_id <- decode.field("room_id", decode.string)
      use user <- decode.field("user", raw_presence_decoder())
      decode.success(RawUserJoined(room_id, user))
    }
    "user_left" -> {
      use room_id <- decode.field("room_id", decode.string)
      use connection_id <- decode.field("connection_id", decode.string)
      decode.success(RawUserLeft(room_id, connection_id))
    }
    "message_sent" -> {
      use room_id <- decode.field("room_id", decode.string)
      use message <- decode.field("message", raw_message_decoder())
      decode.success(RawMessageSent(room_id, message))
    }
    "error" -> {
      use room_id <- decode.field("room_id", decode.optional(decode.string))
      use code <- decode.field("code", decode.string)
      use message <- decode.field("message", decode.string)
      use recoverable <- decode.field("recoverable", decode.bool)
      decode.success(RawError(room_id, code, message, recoverable))
    }
    _ -> decode.success(RawUnknown)
  }
}

fn raw_presence_decoder() -> decode.Decoder(RawPresence) {
  use connection_id <- decode.field("connection_id", decode.string)
  use username <- decode.field("username", decode.string)
  decode.success(RawPresence(connection_id, username))
}

fn raw_message_decoder() -> decode.Decoder(RawMessage) {
  use message_id <- decode.field("message_id", decode.string)
  use sender_id <- decode.field("sender_id", decode.string)
  use username <- decode.field("username", decode.string)
  use text <- decode.field("text", decode.string)
  use sent_at <- decode.field("sent_at", decode.string)
  decode.success(RawMessage(message_id, sender_id, username, text, sent_at))
}

fn trusted_server_event(
  event: RawServerEvent,
) -> Result(domain.ServerEvent, Nil) {
  case event {
    RawRoomState(room_id, self_id, raw_users, raw_messages) -> {
      case list.try_map(raw_users, trusted_presence) {
        Error(_) -> Error(Nil)
        Ok(users) ->
          case list.try_map(raw_messages, trusted_message) {
            Error(_) -> Error(Nil)
            Ok(messages) ->
              Ok(domain.RoomState(
                domain.room_id_from_string(room_id),
                domain.connection_id_from_string(self_id),
                users,
                messages,
              ))
          }
      }
    }
    RawUserJoined(room_id, raw_user) -> {
      case trusted_presence(raw_user) {
        Error(_) -> Error(Nil)
        Ok(user) ->
          Ok(domain.UserJoined(domain.room_id_from_string(room_id), user))
      }
    }
    RawUserLeft(room_id, connection_id) ->
      Ok(domain.UserLeft(
        domain.room_id_from_string(room_id),
        domain.connection_id_from_string(connection_id),
      ))
    RawMessageSent(room_id, raw_message) -> {
      case trusted_message(raw_message) {
        Error(_) -> Error(Nil)
        Ok(message) ->
          Ok(domain.MessageSent(domain.room_id_from_string(room_id), message))
      }
    }
    RawError(room_id, raw_code, message, recoverable) -> {
      case error_code_from_string(raw_code) {
        Error(_) -> Error(Nil)
        Ok(code) ->
          Ok(
            domain.ServerError(domain.ErrorEvent(
              option_room_id(room_id),
              code,
              message,
              recoverable,
            )),
          )
      }
    }
    RawUnknown -> Ok(domain.UnknownEvent)
  }
}

fn trusted_presence(raw: RawPresence) -> Result(domain.Presence, Nil) {
  let RawPresence(connection_id, raw_username) = raw

  case validation.normalize_username(raw_username) {
    Ok(username) ->
      Ok(domain.Presence(
        domain.connection_id_from_string(connection_id),
        username,
      ))
    Error(_) -> Error(Nil)
  }
}

fn trusted_message(raw: RawMessage) -> Result(domain.ChatMessage, Nil) {
  let RawMessage(message_id, sender_id, raw_username, raw_text, sent_at) = raw

  case
    validation.normalize_username(raw_username),
    validation.normalize_message_text(raw_text)
  {
    Ok(username), Ok(text) ->
      Ok(domain.ChatMessage(
        domain.message_id_from_string(message_id),
        domain.connection_id_from_string(sender_id),
        username,
        text,
        sent_at,
      ))
    _, _ -> Error(Nil)
  }
}

fn option_room_id(raw_room_id: Option(String)) -> Option(domain.RoomId) {
  case raw_room_id {
    Some(room_id) -> Some(domain.room_id_from_string(room_id))
    None -> None
  }
}

fn error_code_from_string(raw_code: String) -> Result(domain.ErrorCode, Nil) {
  case raw_code {
    "invalid_event" -> Ok(domain.InvalidEvent)
    "join_required" -> Ok(domain.JoinRequired)
    "already_joined" -> Ok(domain.AlreadyJoined)
    "invalid_room_id" -> Ok(domain.InvalidRoomId)
    "room_not_found" -> Ok(domain.RoomNotFound)
    "room_mismatch" -> Ok(domain.RoomMismatch)
    "room_unavailable" -> Ok(domain.RoomUnavailable)
    "invalid_username" -> Ok(domain.InvalidUsername)
    "invalid_message" -> Ok(domain.InvalidMessage)
    "rate_limited" -> Ok(domain.RateLimited)
    "room_full" -> Ok(domain.RoomFull)
    _ -> Error(Nil)
  }
}
