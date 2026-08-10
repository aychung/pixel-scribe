import gleam/option.{Some}
import pixel_scribe_frontend/domain

pub fn opaque_ids_round_trip_without_crossing_types_test() {
  let default_room = domain.room_id_from_string("default")
  let same_room = domain.room_id_from_string("default")
  let other_room = domain.room_id_from_string("other")
  let connection = domain.connection_id_from_string("connection-1")
  let message = domain.message_id_from_string("message-1")

  assert default_room == same_room
  assert default_room != other_room
  assert domain.room_id_to_string(default_room) == "default"
  assert domain.connection_id_to_string(connection) == "connection-1"
  assert domain.message_id_to_string(message) == "message-1"
  assert domain.default_room_id == default_room
}

pub fn presence_and_messages_keep_wire_fields_explicit_test() {
  let connection = domain.connection_id_from_string("connection-1")
  let message_id = domain.message_id_from_string("message-1")
  let presence = domain.Presence(connection_id: connection, username: "Ada")
  let message =
    domain.ChatMessage(
      message_id: message_id,
      sender_id: connection,
      username: "Ada",
      text: "Hello!\nSecond line",
      sent_at: "2026-08-10T16:00:00Z",
    )

  assert presence.connection_id == connection
  assert presence.username == "Ada"
  assert message.message_id == message_id
  assert message.sender_id == connection
  assert message.username == "Ada"
  assert message.text == "Hello!\nSecond line"
  assert message.sent_at == "2026-08-10T16:00:00Z"
}

pub fn server_events_and_error_codes_have_safe_shapes_test() {
  let room = domain.default_room_id
  let connection = domain.connection_id_from_string("connection-1")
  let message_id = domain.message_id_from_string("message-1")
  let user = domain.Presence(connection, "Ada")
  let message =
    domain.ChatMessage(
      message_id,
      connection,
      "Ada",
      "Hello",
      "2026-08-10T16:00:00Z",
    )

  let snapshot = domain.RoomState(room, connection, [user], [message])
  let joined = domain.UserJoined(room, user)
  let left = domain.UserLeft(room, connection)
  let sent = domain.MessageSent(room, message)
  let error =
    domain.ErrorEvent(
      Some(room),
      domain.InvalidMessage,
      "Message must contain between 1 and 500 characters.",
      True,
    )

  assert snapshot == domain.RoomState(room, connection, [user], [message])
  assert joined == domain.UserJoined(room, user)
  assert left == domain.UserLeft(room, connection)
  assert sent == domain.MessageSent(room, message)
  assert error
    == domain.ErrorEvent(
      Some(room),
      domain.InvalidMessage,
      "Message must contain between 1 and 500 characters.",
      True,
    )

  let server_error = domain.ServerError(error)
  assert server_error == domain.ServerError(error)

  let safe_failure = domain.MalformedServerEvent
  let failure_has_no_payload = case safe_failure {
    domain.MalformedServerEvent -> True
  }
  assert failure_has_no_payload

  let unknown_event_is_payload_free = case domain.UnknownEvent {
    domain.UnknownEvent -> True
  }
  assert unknown_event_is_payload_free
}
