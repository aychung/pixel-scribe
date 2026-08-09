import gleam/bit_array
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import pixel_scribe_backend/domain

pub const max_event_bytes = 8192

pub type ClientFrame {
  TextFrame(String)
  BinaryFrame(BitArray)
}

pub type ClientEvent {
  JoinRoom(room_id: domain.RoomId, username: domain.Username)
  SendMessage(room_id: domain.RoomId, text: domain.MessageText)
}

pub type DecodeError {
  BinaryPayload
  PayloadTooLarge
  MalformedEvent
  InvalidRoomIdValue
  InvalidUsernameValue
  InvalidMessageTextValue
}

pub type ServerEvent {
  RoomState(
    room_id: domain.RoomId,
    self_id: domain.ConnectionId,
    users: List(domain.Presence),
    messages: List(domain.ChatMessage),
  )
  UserJoined(room_id: domain.RoomId, user: domain.Presence)
  UserLeft(room_id: domain.RoomId, connection_id: domain.ConnectionId)
  MessageSent(room_id: domain.RoomId, message: domain.ChatMessage)
  ErrorEvent(room_id: Option(domain.RoomId), code: ErrorCode)
}

pub type ErrorCode {
  InvalidEvent
  JoinRequired
  AlreadyJoined
  InvalidRoomId
  RoomNotFound
  RoomMismatch
  RoomUnavailable
  InvalidUsername
  InvalidMessage
  RateLimited
  RoomFull
}

type RawClientEvent {
  RawInvalid
  RawJoinRoom(room_id: String, username: String)
  RawSendMessage(room_id: String, text: String)
}

pub fn decode_client_event(
  frame: ClientFrame,
) -> Result(ClientEvent, DecodeError) {
  case frame {
    BinaryFrame(_) -> Error(BinaryPayload)
    TextFrame(payload) -> {
      let bytes = payload |> bit_array.from_string |> bit_array.byte_size

      case bytes > max_event_bytes {
        True -> Error(PayloadTooLarge)
        False ->
          case json.parse(from: payload, using: raw_client_event_decoder()) {
            Ok(event) -> validate_raw_event(event)
            Error(_) -> Error(MalformedEvent)
          }
      }
    }
  }
}

fn raw_client_event_decoder() -> decode.Decoder(RawClientEvent) {
  use event_type <- decode.field("type", decode.string)

  case event_type {
    "join_room" -> {
      use room_id <- decode.field("room_id", decode.string)
      use username <- decode.field("username", decode.string)
      decode.success(RawJoinRoom(room_id, username))
    }
    "send_message" -> {
      use room_id <- decode.field("room_id", decode.string)
      use text <- decode.field("text", decode.string)
      decode.success(RawSendMessage(room_id, text))
    }
    _ -> decode.failure(RawInvalid, expected: "known client event")
  }
}

fn validate_raw_event(
  event: RawClientEvent,
) -> Result(ClientEvent, DecodeError) {
  case event {
    RawInvalid -> Error(MalformedEvent)
    RawJoinRoom(raw_room_id, raw_username) -> {
      case domain.new_room_id(raw_room_id) {
        Error(_) -> Error(InvalidRoomIdValue)
        Ok(room_id) ->
          case domain.new_username(raw_username) {
            Error(_) -> Error(InvalidUsernameValue)
            Ok(username) -> Ok(JoinRoom(room_id, username))
          }
      }
    }
    RawSendMessage(raw_room_id, raw_text) -> {
      case domain.new_room_id(raw_room_id) {
        Error(_) -> Error(InvalidRoomIdValue)
        Ok(room_id) ->
          case domain.new_message_text(raw_text) {
            Error(_) -> Error(InvalidMessageTextValue)
            Ok(text) -> Ok(SendMessage(room_id, text))
          }
      }
    }
  }
}

pub fn decode_error_to_error_code(error: DecodeError) -> ErrorCode {
  case error {
    BinaryPayload | PayloadTooLarge | MalformedEvent -> InvalidEvent
    InvalidRoomIdValue -> InvalidRoomId
    InvalidUsernameValue -> InvalidUsername
    InvalidMessageTextValue -> InvalidMessage
  }
}

pub fn error_code_to_string(code: ErrorCode) -> String {
  case code {
    InvalidEvent -> "invalid_event"
    JoinRequired -> "join_required"
    AlreadyJoined -> "already_joined"
    InvalidRoomId -> "invalid_room_id"
    RoomNotFound -> "room_not_found"
    RoomMismatch -> "room_mismatch"
    RoomUnavailable -> "room_unavailable"
    InvalidUsername -> "invalid_username"
    InvalidMessage -> "invalid_message"
    RateLimited -> "rate_limited"
    RoomFull -> "room_full"
  }
}

pub fn error_message(code: ErrorCode) -> String {
  case code {
    InvalidEvent -> "Invalid event."
    JoinRequired -> "Join a room before sending messages."
    AlreadyJoined -> "This connection has already joined a room."
    InvalidRoomId -> "Room ID is invalid."
    RoomNotFound -> "Room not found."
    RoomMismatch -> "Room ID does not match the joined room."
    RoomUnavailable -> "Room is unavailable. Reconnect to continue."
    InvalidUsername -> "Username must contain between 1 and 32 characters."
    InvalidMessage -> "Message must contain between 1 and 500 characters."
    RateLimited -> "You are sending messages too quickly."
    RoomFull -> "Room is full."
  }
}

pub fn error_is_recoverable(code: ErrorCode) -> Bool {
  case code {
    InvalidEvent | RoomUnavailable | RoomFull -> False
    JoinRequired
    | AlreadyJoined
    | InvalidRoomId
    | RoomNotFound
    | RoomMismatch
    | InvalidUsername
    | InvalidMessage
    | RateLimited -> True
  }
}

pub fn encode_server_event(event: ServerEvent) -> String {
  event
  |> server_event_to_json
  |> json.to_string
}

fn server_event_to_json(event: ServerEvent) -> json.Json {
  case event {
    RoomState(room_id, self_id, users, messages) ->
      json.object([
        #("type", json.string("room_state")),
        #("room_id", json.string(domain.room_id_to_string(room_id))),
        #("self_id", json.string(domain.connection_id_to_string(self_id))),
        #("users", json.array(users, of: presence_to_json)),
        #("messages", json.array(messages, of: message_to_json)),
      ])
    UserJoined(room_id, user) ->
      json.object([
        #("type", json.string("user_joined")),
        #("room_id", json.string(domain.room_id_to_string(room_id))),
        #("user", presence_to_json(user)),
      ])
    UserLeft(room_id, connection_id) ->
      json.object([
        #("type", json.string("user_left")),
        #("room_id", json.string(domain.room_id_to_string(room_id))),
        #(
          "connection_id",
          json.string(domain.connection_id_to_string(connection_id)),
        ),
      ])
    MessageSent(room_id, message) ->
      json.object([
        #("type", json.string("message_sent")),
        #("room_id", json.string(domain.room_id_to_string(room_id))),
        #("message", message_to_json(message)),
      ])
    ErrorEvent(room_id, code) ->
      json.object([
        #("type", json.string("error")),
        #("room_id", optional_room_id_to_json(room_id)),
        #("code", json.string(error_code_to_string(code))),
        #("message", json.string(error_message(code))),
        #("recoverable", json.bool(error_is_recoverable(code))),
      ])
  }
}

fn optional_room_id_to_json(room_id: Option(domain.RoomId)) -> json.Json {
  case room_id {
    Some(room_id) -> json.string(domain.room_id_to_string(room_id))
    None -> json.null()
  }
}

fn presence_to_json(presence: domain.Presence) -> json.Json {
  json.object([
    #(
      "connection_id",
      presence
        |> domain.presence_connection_id
        |> domain.connection_id_to_string
        |> json.string,
    ),
    #(
      "username",
      presence
        |> domain.presence_username
        |> domain.username_to_string
        |> json.string,
    ),
  ])
}

fn message_to_json(message: domain.ChatMessage) -> json.Json {
  json.object([
    #(
      "message_id",
      message
        |> domain.chat_message_message_id
        |> domain.message_id_to_string
        |> json.string,
    ),
    #(
      "sender_id",
      message
        |> domain.chat_message_sender_id
        |> domain.connection_id_to_string
        |> json.string,
    ),
    #(
      "username",
      message
        |> domain.chat_message_username
        |> domain.username_to_string
        |> json.string,
    ),
    #(
      "text",
      message
        |> domain.chat_message_text
        |> domain.message_text_to_string
        |> json.string,
    ),
    #(
      "sent_at",
      message
        |> domain.chat_message_sent_at
        |> domain.sent_at_to_rfc3339
        |> json.string,
    ),
  ])
}
