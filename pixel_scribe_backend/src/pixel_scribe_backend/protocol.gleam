import gleam/bit_array
import gleam/dynamic/decode
import gleam/json
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
