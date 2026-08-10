import gleam/bit_array
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import pixel_scribe_backend/domain
import pixel_scribe_backend/protocol

pub fn join_room_payload_decodes_to_validated_event_test() {
  let payload =
    protocol.TextFrame(
      "{\"type\":\"join_room\",\"room_id\":\"default\",\"username\":\"  Ada  \"}",
    )

  let assert Ok(protocol.JoinRoom(room_id, username)) =
    protocol.decode_client_event(payload)

  assert domain.room_id_to_string(room_id) == "default"
  assert domain.username_to_string(username) == "Ada"
}

pub fn send_message_payload_decodes_to_validated_event_test() {
  let payload =
    protocol.TextFrame(
      "{\"type\":\"send_message\",\"room_id\":\"default\",\"text\":\"  Hello!  \"}",
    )

  let assert Ok(protocol.SendMessage(room_id, text)) =
    protocol.decode_client_event(payload)

  assert domain.room_id_to_string(room_id) == "default"
  assert domain.message_text_to_string(text) == "Hello!"
}

pub fn client_event_decoder_requires_snake_case_fields_test() {
  let payload =
    protocol.TextFrame(
      "{\"type\":\"join_room\",\"roomId\":\"default\",\"username\":\"Ada\"}",
    )

  assert protocol.decode_client_event(payload) == Error(protocol.MalformedEvent)
}

pub fn client_event_decoder_rejects_unknown_and_malformed_events_test() {
  assert protocol.decode_client_event(protocol.TextFrame("not json"))
    == Error(protocol.MalformedEvent)

  assert protocol.decode_client_event(protocol.TextFrame(
      "{\"type\":\"leave_room\",\"room_id\":\"default\"}",
    ))
    == Error(protocol.MalformedEvent)

  assert protocol.decode_client_event(protocol.TextFrame(
      "{\"type\":\"join_room\",\"room_id\":null}",
    ))
    == Error(protocol.MalformedEvent)
}

pub fn client_event_decoder_rejects_invalid_domain_values_test() {
  assert protocol.decode_client_event(protocol.TextFrame(
      "{\"type\":\"join_room\",\"room_id\":\"Default\",\"username\":\"Ada\"}",
    ))
    == Error(protocol.InvalidRoomIdValue)

  assert protocol.decode_client_event(protocol.TextFrame(
      "{\"type\":\"join_room\",\"room_id\":\"default\",\"username\":\"   \"}",
    ))
    == Error(protocol.InvalidUsernameValue)

  assert protocol.decode_client_event(protocol.TextFrame(
      "{\"type\":\"send_message\",\"room_id\":\"default\",\"text\":\"Hello\\rworld\"}",
    ))
    == Error(protocol.InvalidMessageTextValue)
}

pub fn client_event_decoder_accepts_multiline_messages_test() {
  let assert Ok(protocol.SendMessage(room_id, text)) =
    protocol.decode_client_event(protocol.TextFrame(
      "{\"type\":\"send_message\",\"room_id\":\"default\",\"text\":\"First line\\nSecond line\"}",
    ))

  assert domain.room_id_to_string(room_id) == "default"
  assert domain.message_text_to_string(text) == "First line\nSecond line"
}

pub fn decode_failures_preserve_valid_room_context_test() {
  let assert Error(protocol.DecodeFailure(error, Some(room_id))) =
    protocol.decode_client_event_with_context(protocol.TextFrame(
      "{\"type\":\"send_message\",\"room_id\":\"default\",\"text\":\"   \"}",
    ))

  assert error == protocol.InvalidMessageTextValue
  assert room_id == domain.default_room_id

  let assert Error(protocol.DecodeFailure(_, None)) =
    protocol.decode_client_event_with_context(protocol.TextFrame(
      "{\"type\":\"send_message\",\"room_id\":\"Default\",\"text\":\"Hello\"}",
    ))
  Nil
}

pub fn binary_frames_are_rejected_before_json_decoding_test() {
  let payload = bit_array.from_string("{\"type\":\"join_room\"}")

  assert protocol.decode_client_event(protocol.BinaryFrame(payload))
    == Error(protocol.BinaryPayload)
}

pub fn event_size_limit_accepts_8_kib_and_rejects_more_test() {
  let prefix =
    "{\"type\":\"join_room\",\"room_id\":\"default\",\"username\":\"Ada\",\"padding\":\""
  let suffix = "\"}"
  let padding_length =
    protocol.max_event_bytes - string.length(prefix) - string.length(suffix)
  let exact_payload = prefix <> string.repeat("x", padding_length) <> suffix
  let oversized_payload =
    prefix <> string.repeat("x", padding_length + 1) <> suffix

  let assert Ok(protocol.JoinRoom(_, _)) =
    protocol.decode_client_event(protocol.TextFrame(exact_payload))
  assert protocol.decode_client_event(protocol.TextFrame(oversized_payload))
    == Error(protocol.PayloadTooLarge)
}

pub fn room_state_event_encodes_exactly_test() {
  let connection_id = domain.new_connection_id()
  let assert Ok(username) = domain.new_username("Ada")
  let presence = domain.Presence(connection_id, username)
  let event =
    protocol.RoomState(domain.default_room_id, connection_id, [presence], [])
  let connection_id_string = domain.connection_id_to_string(connection_id)

  assert protocol.encode_server_event(event)
    == "{\"type\":\"room_state\",\"room_id\":\"default\",\"self_id\":\""
    <> connection_id_string
    <> "\",\"users\":[{\"connection_id\":\""
    <> connection_id_string
    <> "\",\"username\":\"Ada\"}],\"messages\":[]}"
}

pub fn user_joined_event_encodes_exactly_test() {
  let connection_id = domain.new_connection_id()
  let assert Ok(username) = domain.new_username("Grace")
  let presence = domain.Presence(connection_id, username)
  let event = protocol.UserJoined(domain.default_room_id, presence)
  let connection_id_string = domain.connection_id_to_string(connection_id)

  assert protocol.encode_server_event(event)
    == "{\"type\":\"user_joined\",\"room_id\":\"default\",\"user\":{\"connection_id\":\""
    <> connection_id_string
    <> "\",\"username\":\"Grace\"}}"
}

pub fn user_left_event_encodes_exactly_test() {
  let connection_id = domain.new_connection_id()
  let connection_id_string = domain.connection_id_to_string(connection_id)
  let event = protocol.UserLeft(domain.default_room_id, connection_id)

  assert protocol.encode_server_event(event)
    == "{\"type\":\"user_left\",\"room_id\":\"default\",\"connection_id\":\""
    <> connection_id_string
    <> "\"}"
}

pub fn message_sent_event_encodes_exactly_test() {
  let connection_id = domain.new_connection_id()
  let message_id = domain.new_message_id()
  let assert Ok(username) = domain.new_username("Ada")
  let assert Ok(text) = domain.new_message_text("Hello!")
  let sent_at = domain.new_sent_at()
  let message =
    domain.ChatMessage(message_id, connection_id, username, text, sent_at)
  let event = protocol.MessageSent(domain.default_room_id, message)
  let message_id_string = domain.message_id_to_string(message_id)
  let connection_id_string = domain.connection_id_to_string(connection_id)
  let sent_at_string = domain.sent_at_to_rfc3339(sent_at)

  assert protocol.encode_server_event(event)
    == "{\"type\":\"message_sent\",\"room_id\":\"default\",\"message\":{\"message_id\":\""
    <> message_id_string
    <> "\",\"sender_id\":\""
    <> connection_id_string
    <> "\",\"username\":\"Ada\",\"text\":\"Hello!\",\"sent_at\":\""
    <> sent_at_string
    <> "\"}}"
}

pub fn server_event_encoder_escapes_user_text_test() {
  let connection_id = domain.new_connection_id()
  let message_id = domain.new_message_id()
  let assert Ok(username) = domain.new_username("Ada \"Ace\"")
  let assert Ok(text) = domain.new_message_text("say \"hello\" \\ now")
  let message =
    domain.ChatMessage(
      message_id,
      connection_id,
      username,
      text,
      domain.new_sent_at(),
    )
  let encoded =
    protocol.encode_server_event(protocol.MessageSent(
      domain.default_room_id,
      message,
    ))

  assert string.contains(encoded, "\"username\":\"Ada \\\"Ace\\\"\"")
  assert string.contains(encoded, "\"text\":\"say \\\"hello\\\" \\\\ now\"")
}

pub fn structured_errors_encode_context_and_metadata_test() {
  assert protocol.encode_server_event(protocol.ErrorEvent(
      Some(domain.default_room_id),
      protocol.InvalidMessage,
    ))
    == "{\"type\":\"error\",\"room_id\":\"default\",\"code\":\"invalid_message\",\"message\":\"Message must contain between 1 and 500 characters.\",\"recoverable\":true}"

  assert protocol.encode_server_event(protocol.ErrorEvent(
      None,
      protocol.InvalidEvent,
    ))
    == "{\"type\":\"error\",\"room_id\":null,\"code\":\"invalid_event\",\"message\":\"Invalid event.\",\"recoverable\":false}"
}

pub fn every_error_code_has_stable_wire_metadata_test() {
  let cases = [
    #(protocol.InvalidEvent, "invalid_event", "Invalid event.", False),
    #(
      protocol.JoinRequired,
      "join_required",
      "Join a room before sending messages.",
      True,
    ),
    #(
      protocol.AlreadyJoined,
      "already_joined",
      "This connection has already joined a room.",
      True,
    ),
    #(protocol.InvalidRoomId, "invalid_room_id", "Room ID is invalid.", True),
    #(protocol.RoomNotFound, "room_not_found", "Room not found.", True),
    #(
      protocol.RoomMismatch,
      "room_mismatch",
      "Room ID does not match the joined room.",
      True,
    ),
    #(
      protocol.RoomUnavailable,
      "room_unavailable",
      "Room is unavailable. Reconnect to continue.",
      False,
    ),
    #(
      protocol.InvalidUsername,
      "invalid_username",
      "Username must contain between 1 and 32 characters.",
      True,
    ),
    #(
      protocol.InvalidMessage,
      "invalid_message",
      "Message must contain between 1 and 500 characters.",
      True,
    ),
    #(
      protocol.RateLimited,
      "rate_limited",
      "You are sending messages too quickly.",
      True,
    ),
    #(protocol.RoomFull, "room_full", "Room is full.", False),
  ]

  list.each(cases, fn(item) {
    let #(code, expected_wire_code, expected_message, expected_recoverable) =
      item
    let expected_recoverable_json = case expected_recoverable {
      True -> "true"
      False -> "false"
    }
    let expected_wire =
      "{\"type\":\"error\",\"room_id\":null,\"code\":\""
      <> expected_wire_code
      <> "\",\"message\":\""
      <> expected_message
      <> "\",\"recoverable\":"
      <> expected_recoverable_json
      <> "}"

    assert protocol.error_code_to_string(code) == expected_wire_code
    assert protocol.error_message(code) == expected_message
    assert protocol.error_is_recoverable(code) == expected_recoverable
    assert protocol.encode_server_event(protocol.ErrorEvent(None, code))
      == expected_wire
  })
}
