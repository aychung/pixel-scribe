import gleam/list
import gleam/string

pub type RoomIdError {
  InvalidRoomId
}

pub type UsernameError {
  UsernameEmpty
  UsernameTooLong
  UsernameContainsControlCharacter
}

pub type MessageTextError {
  MessageTextEmpty
  MessageTextTooLong
  MessageTextContainsControlCharacter
}

const max_room_id_length = 64

const max_username_length = 32

const max_message_text_length = 500

pub fn normalize_room_id(input: String) -> Result(String, RoomIdError) {
  let codepoints =
    input
    |> string.to_utf_codepoints
    |> list.map(string.utf_codepoint_to_int)

  case codepoints {
    [] -> Error(InvalidRoomId)
    [first, ..rest] -> {
      let valid =
        list.length(codepoints) <= max_room_id_length
        && is_ascii_letter_or_digit(first)
        && list.all(rest, is_room_id_tail)

      case valid {
        True -> Ok(input)
        False -> Error(InvalidRoomId)
      }
    }
  }
}

pub fn normalize_username(input: String) -> Result(String, UsernameError) {
  case normalize_text(input, max_username_length) {
    Ok(value) -> Ok(value)
    Error(TextEmpty) -> Error(UsernameEmpty)
    Error(TextTooLong) -> Error(UsernameTooLong)
    Error(TextContainsControlCharacter) ->
      Error(UsernameContainsControlCharacter)
  }
}

pub fn normalize_message_text(
  input: String,
) -> Result(String, MessageTextError) {
  case normalize_text(input, max_message_text_length) {
    Ok(value) -> Ok(value)
    Error(TextEmpty) -> Error(MessageTextEmpty)
    Error(TextTooLong) -> Error(MessageTextTooLong)
    Error(TextContainsControlCharacter) ->
      Error(MessageTextContainsControlCharacter)
  }
}

type TextError {
  TextEmpty
  TextTooLong
  TextContainsControlCharacter
}

fn normalize_text(input: String, max_length: Int) -> Result(String, TextError) {
  case contains_control_character(input) {
    True -> Error(TextContainsControlCharacter)
    False -> {
      let normalized = string.trim(input)

      case normalized {
        "" -> Error(TextEmpty)
        _ ->
          case string.length(normalized) > max_length {
            True -> Error(TextTooLong)
            False -> Ok(normalized)
          }
      }
    }
  }
}

fn contains_control_character(input: String) -> Bool {
  input
  |> string.to_utf_codepoints
  |> list.map(string.utf_codepoint_to_int)
  |> list.any(is_control_character)
}

fn is_control_character(codepoint: Int) -> Bool {
  codepoint <= 31
  || codepoint >= 127
  && codepoint <= 159
  || codepoint == 0x2028
  || codepoint == 0x2029
}

fn is_ascii_letter_or_digit(codepoint: Int) -> Bool {
  codepoint >= 48 && codepoint <= 57 || codepoint >= 97 && codepoint <= 122
}

fn is_room_id_tail(codepoint: Int) -> Bool {
  is_ascii_letter_or_digit(codepoint) || codepoint == 95 || codepoint == 45
}
