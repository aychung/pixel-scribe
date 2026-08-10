import gleam/list
import gleam/string
import pixel_scribe_frontend/validation

pub fn usernames_are_trimmed_and_counted_by_grapheme_test() {
  let assert Ok(username) = validation.normalize_username("  Ada 👩🏽‍💻  ")
  assert username == "Ada 👩🏽‍💻"

  let assert Ok(_) = validation.normalize_username(string.repeat("a", 32))
  assert validation.normalize_username(string.repeat("a", 33))
    == Error(validation.UsernameTooLong)

  let assert Ok(_) = validation.normalize_username(string.repeat("👩🏽‍💻", 32))
  assert validation.normalize_username(string.repeat("👩🏽‍💻", 33))
    == Error(validation.UsernameTooLong)

  let assert Ok(_) =
    validation.normalize_username(string.repeat("e\u{301}", 32))
  assert validation.normalize_username(string.repeat("e\u{301}", 33))
    == Error(validation.UsernameTooLong)
}

pub fn usernames_reject_empty_and_controls_before_trimming_test() {
  assert validation.normalize_username("") == Error(validation.UsernameEmpty)
  assert validation.normalize_username("   ") == Error(validation.UsernameEmpty)
  assert validation.normalize_username(" \n ")
    == Error(validation.UsernameContainsControlCharacter)

  let invalid_codepoints =
    list.append(codepoints(0, 31), codepoints(127, 159))
    |> list.append([0x2028, 0x2029])

  assert list.all(invalid_codepoints, fn(codepoint) {
    validation.normalize_username("Ada" <> character(codepoint) <> "User")
    == Error(validation.UsernameContainsControlCharacter)
  })
}

pub fn messages_are_trimmed_and_counted_by_grapheme_test() {
  let assert Ok(message) = validation.normalize_message_text("  e\u{301}  ")
  assert message == "e\u{301}"

  let assert Ok(message) =
    validation.normalize_message_text("  First line\nSecond line  ")
  assert message == "First line\nSecond line"

  let assert Ok(_) =
    validation.normalize_message_text(
      string.repeat("a", 250) <> "\n" <> string.repeat("a", 249),
    )
  assert validation.normalize_message_text(
      string.repeat("a", 250) <> "\n" <> string.repeat("a", 250),
    )
    == Error(validation.MessageTextTooLong)

  let assert Ok(_) = validation.normalize_message_text(string.repeat("👩🏽‍💻", 500))
  assert validation.normalize_message_text(string.repeat("👩🏽‍💻", 501))
    == Error(validation.MessageTextTooLong)

  let assert Ok(_) =
    validation.normalize_message_text(string.repeat("e\u{301}", 500))
  assert validation.normalize_message_text(string.repeat("e\u{301}", 501))
    == Error(validation.MessageTextTooLong)
}

pub fn messages_allow_lf_but_reject_other_controls_test() {
  let assert Ok(message) = validation.normalize_message_text("First\nSecond")
  assert message == "First\nSecond"
  assert validation.normalize_message_text("")
    == Error(validation.MessageTextEmpty)
  assert validation.normalize_message_text("   ")
    == Error(validation.MessageTextEmpty)
  assert validation.normalize_message_text(" \n ")
    == Error(validation.MessageTextEmpty)

  let invalid_codepoints =
    list.append(codepoints(0, 9), codepoints(11, 31))
    |> list.append(codepoints(127, 159))
    |> list.append([0x2028, 0x2029])

  assert list.all(invalid_codepoints, fn(codepoint) {
    validation.normalize_message_text(
      "Before" <> character(codepoint) <> "After",
    )
    == Error(validation.MessageTextContainsControlCharacter)
  })

  assert validation.normalize_message_text("Before\r\nAfter")
    == Error(validation.MessageTextContainsControlCharacter)
  assert validation.normalize_message_text("Before\rAfter")
    == Error(validation.MessageTextContainsControlCharacter)
}

fn character(codepoint: Int) -> String {
  let assert Ok(value) = string.utf_codepoint(codepoint)
  string.from_utf_codepoints([value])
}

fn codepoints(first: Int, last: Int) -> List(Int) {
  case first > last {
    True -> []
    False -> [first, ..codepoints(first + 1, last)]
  }
}
