import gleam/string
import pixel_scribe_backend/validation

pub fn room_ids_accept_only_the_approved_shape_test() {
  assert validation.normalize_room_id("default") == Ok("default")
  assert validation.normalize_room_id("room_01-alpha") == Ok("room_01-alpha")
  assert validation.normalize_room_id("1") == Ok("1")
  let assert Ok(_) = validation.normalize_room_id(string.repeat("a", 64))

  assert validation.normalize_room_id("") == Error(validation.InvalidRoomId)
  assert validation.normalize_room_id("_room")
    == Error(validation.InvalidRoomId)
  assert validation.normalize_room_id("room!")
    == Error(validation.InvalidRoomId)
  assert validation.normalize_room_id("Room") == Error(validation.InvalidRoomId)
  assert validation.normalize_room_id(string.repeat("a", 65))
    == Error(validation.InvalidRoomId)
}

pub fn usernames_are_trimmed_and_counted_by_grapheme_test() {
  let assert Ok(username) = validation.normalize_username("  Ada 👩🏽‍💻  ")
  assert username == "Ada 👩🏽‍💻"

  let assert Ok(_) = validation.normalize_username(string.repeat("👩🏽‍💻", 32))
  assert validation.normalize_username(string.repeat("👩🏽‍💻", 33))
    == Error(validation.UsernameTooLong)

  let assert Ok(_) = validation.normalize_username("👩🏽‍💻")
  assert validation.normalize_username("   ") == Error(validation.UsernameEmpty)
}

pub fn messages_are_trimmed_and_counted_by_grapheme_test() {
  let assert Ok(message) = validation.normalize_message_text("  e\u{301}  ")
  assert message == "e\u{301}"

  let assert Ok(message) =
    validation.normalize_message_text("First line\nSecond line")
  assert message == "First line\nSecond line"

  let assert Ok(_) = validation.normalize_message_text(string.repeat("👩🏽‍💻", 500))
  assert validation.normalize_message_text(string.repeat("👩🏽‍💻", 501))
    == Error(validation.MessageTextTooLong)
  assert validation.normalize_message_text(" \t ")
    == Error(validation.MessageTextContainsControlCharacter)
}

pub fn usernames_reject_control_characters_and_messages_reject_non_lf_controls_test() {
  assert validation.normalize_username("Ada\nLovelace")
    == Error(validation.UsernameContainsControlCharacter)
  assert validation.normalize_username("\nAda")
    == Error(validation.UsernameContainsControlCharacter)
  assert validation.normalize_username("Ada\u{2028}Lovelace")
    == Error(validation.UsernameContainsControlCharacter)

  assert validation.normalize_message_text("Hello\rworld")
    == Error(validation.MessageTextContainsControlCharacter)
  assert validation.normalize_message_text("Hello\u{85}world")
    == Error(validation.MessageTextContainsControlCharacter)
}
