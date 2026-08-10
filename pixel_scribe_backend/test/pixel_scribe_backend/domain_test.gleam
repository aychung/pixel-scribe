import gleam/string
import gleam/time/timestamp
import pixel_scribe_backend/domain
import pixel_scribe_backend/validation

pub fn default_room_id_is_a_stable_domain_constant_test() {
  assert domain.room_id_to_string(domain.default_room_id) == "default"
  let assert Ok(room_id) = domain.new_room_id("future-room")
  assert domain.room_id_to_string(room_id) == "future-room"
  assert domain.new_room_id("not a room") == Error(validation.InvalidRoomId)
}

pub fn generated_ids_are_opaque_and_unique_for_the_server_lifetime_test() {
  let first_connection = domain.new_connection_id()
  let second_connection = domain.new_connection_id()
  let first_message = domain.new_message_id()
  let second_message = domain.new_message_id()

  assert first_connection != second_connection
  assert first_message != second_message
  assert domain.connection_id_to_string(first_connection)
    |> string.starts_with("connection-")
  assert domain.message_id_to_string(first_message)
    |> string.starts_with("message-")
  assert domain.connection_id_to_string(first_connection)
    != domain.message_id_to_string(first_message)
}

pub fn timestamps_serialize_as_utc_rfc3339_test() {
  let sent_at = domain.new_sent_at()
  let encoded = domain.sent_at_to_rfc3339(sent_at)

  assert string.ends_with(encoded, "Z")
  let assert Ok(_) = timestamp.parse_rfc3339(encoded)
}

pub fn presence_and_chat_message_hold_validated_domain_values_test() {
  let assert Ok(username) = domain.new_username(" Ada ")
  let assert Ok(text) = domain.new_message_text(" Hello ")
  assert domain.new_username("Ada\nLovelace")
    == Error(validation.UsernameContainsControlCharacter)
  assert domain.new_message_text("   ") == Error(validation.MessageTextEmpty)
  let connection_id = domain.new_connection_id()
  let message_id = domain.new_message_id()
  let sent_at = domain.new_sent_at()
  let presence = domain.Presence(connection_id, username)
  let message =
    domain.ChatMessage(message_id, connection_id, username, text, sent_at)

  assert presence.connection_id == connection_id
  assert presence.username == username
  assert message.message_id == message_id
  assert message.sender_id == connection_id
  assert message.username == username
  assert message.text == text
  assert message.sent_at == sent_at
}
