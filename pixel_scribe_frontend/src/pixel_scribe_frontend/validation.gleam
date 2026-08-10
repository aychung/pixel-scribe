import gleam/list
import gleam/string

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

const max_username_length = 32

const max_message_text_length = 500

pub fn normalize_username(input: String) -> Result(String, UsernameError) {
  case normalize_text(input, max_username_length, False) {
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
  case normalize_text(input, max_message_text_length, True) {
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

fn normalize_text(
  input: String,
  max_length: Int,
  allow_newlines: Bool,
) -> Result(String, TextError) {
  case contains_control_character(input, allow_newlines) {
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

fn contains_control_character(input: String, allow_newlines: Bool) -> Bool {
  input
  |> string.to_utf_codepoints
  |> list.map(string.utf_codepoint_to_int)
  |> list.any(fn(codepoint) { is_control_character(codepoint, allow_newlines) })
}

fn is_control_character(codepoint: Int, allow_newlines: Bool) -> Bool {
  let is_allowed_newline = allow_newlines && codepoint == 10

  case is_allowed_newline {
    True -> False
    False ->
      codepoint <= 31
      || { codepoint >= 127 && codepoint <= 159 }
      || codepoint == 0x2028
      || codepoint == 0x2029
  }
}
