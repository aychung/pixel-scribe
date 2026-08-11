import gleam/list
import gleam/option.{None, Some}
import gleam/string
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/protocol

pub fn join_room_encoder_emits_the_canonical_default_event_test() {
  let assert Ok(encoded) = protocol.encode_join_room("Ada")

  assert encoded
    == "{\"type\":\"join_room\",\"room_id\":\"default\",\"username\":\"Ada\"}"
}

pub fn send_message_encoder_emits_the_canonical_default_event_test() {
  let assert Ok(encoded) = protocol.encode_send_message("Hello!")

  assert encoded
    == "{\"type\":\"send_message\",\"room_id\":\"default\",\"text\":\"Hello!\"}"
}

pub fn client_event_encoders_escape_text_as_json_strings_test() {
  let assert Ok(joined) = protocol.encode_join_room("Ada \"Ace\"")
  let assert Ok(sent) = protocol.encode_send_message("say \"hello\"\nnext")

  assert joined
    == "{\"type\":\"join_room\",\"room_id\":\"default\",\"username\":\"Ada \\\"Ace\\\"\"}"
  assert sent
    == "{\"type\":\"send_message\",\"room_id\":\"default\",\"text\":\"say \\\"hello\\\"\\nnext\"}"
}

pub fn join_room_encoder_accepts_exactly_8192_utf8_bytes_test() {
  let rich_prefix = "é\"\\\\\n"
  let assert Ok(prefix_frame) = protocol.encode_join_room(rich_prefix)
  let padding = protocol.max_event_bytes - utf8_size(prefix_frame)
  let username = rich_prefix <> string.repeat("x", padding)

  let assert Ok(frame) = protocol.encode_join_room(username)
  assert utf8_size(frame) == protocol.max_event_bytes

  let assert Error(protocol.FrameTooLarge) =
    protocol.encode_join_room(username <> "x")
}

pub fn send_message_encoder_accepts_exactly_8192_utf8_bytes_test() {
  let rich_prefix = "é\"\\\\\n"
  let assert Ok(prefix_frame) = protocol.encode_send_message(rich_prefix)
  let padding = protocol.max_event_bytes - utf8_size(prefix_frame)
  let text = rich_prefix <> string.repeat("x", padding)

  let assert Ok(frame) = protocol.encode_send_message(text)
  assert utf8_size(frame) == protocol.max_event_bytes

  let assert Error(protocol.FrameTooLarge) =
    protocol.encode_send_message(text <> "x")
}

fn utf8_size(value: String) -> Int {
  string.byte_size(value)
}

pub fn room_state_decodes_exact_event_and_ignores_additive_fields_test() {
  let payload =
    "{\"type\":\"room_state\",\"room_id\":\"default\",\"self_id\":\"connection-123\",\"users\":[{\"connection_id\":\"connection-123\",\"username\":\"Ada\"}],\"messages\":[{\"message_id\":\"message-789\",\"sender_id\":\"connection-123\",\"username\":\"Ada\",\"text\":\"Hello!\",\"sent_at\":\"2026-08-08T20:15:00Z\",\"future_message_field\":true}],\"future_event_field\":{\"ignored\":true}}"

  let assert Ok(domain.RoomState(room_id, self_id, users, messages)) =
    protocol.decode_server_event(payload)
  assert room_id == domain.default_room_id
  assert domain.connection_id_to_string(self_id) == "connection-123"
  assert users
    == [
      domain.Presence(domain.connection_id_from_string("connection-123"), "Ada"),
    ]
  assert messages
    == [
      domain.ChatMessage(
        domain.message_id_from_string("message-789"),
        domain.connection_id_from_string("connection-123"),
        "Ada",
        "Hello!",
        "2026-08-08T20:15:00Z",
      ),
    ]
}

pub fn presence_and_message_server_events_decode_exactly_test() {
  let assert Ok(domain.UserJoined(room_id, user)) =
    protocol.decode_server_event(
      "{\"type\":\"user_joined\",\"room_id\":\"default\",\"user\":{\"connection_id\":\"connection-456\",\"username\":\"Grace\"}}",
    )
  assert room_id == domain.default_room_id
  assert user
    == domain.Presence(
      domain.connection_id_from_string("connection-456"),
      "Grace",
    )

  let assert Ok(domain.UserLeft(left_room, connection_id)) =
    protocol.decode_server_event(
      "{\"type\":\"user_left\",\"room_id\":\"default\",\"connection_id\":\"connection-456\"}",
    )
  assert left_room == domain.default_room_id
  assert domain.connection_id_to_string(connection_id) == "connection-456"

  let assert Ok(domain.MessageSent(message_room, message)) =
    protocol.decode_server_event(
      "{\"type\":\"message_sent\",\"room_id\":\"default\",\"message\":{\"message_id\":\"message-789\",\"sender_id\":\"connection-123\",\"username\":\"Ada\",\"text\":\"First line\\nSecond line\",\"sent_at\":\"2026-08-08T20:15:00Z\"}}",
    )
  assert message_room == domain.default_room_id
  assert message
    == domain.ChatMessage(
      domain.message_id_from_string("message-789"),
      domain.connection_id_from_string("connection-123"),
      "Ada",
      "First line\nSecond line",
      "2026-08-08T20:15:00Z",
    )
}

pub fn error_server_events_decode_string_and_null_room_context_test() {
  let assert Ok(domain.ServerError(error)) =
    protocol.decode_server_event(
      "{\"type\":\"error\",\"room_id\":\"default\",\"code\":\"invalid_message\",\"message\":\"Message must contain between 1 and 500 characters.\",\"recoverable\":true}",
    )
  assert error
    == domain.ErrorEvent(
      Some(domain.default_room_id),
      domain.InvalidMessage,
      "Message must contain between 1 and 500 characters.",
      True,
    )

  let assert Ok(domain.ServerError(no_room_error)) =
    protocol.decode_server_event(
      "{\"type\":\"error\",\"room_id\":null,\"code\":\"invalid_event\",\"message\":\"Invalid event.\",\"recoverable\":false}",
    )
  assert no_room_error
    == domain.ErrorEvent(None, domain.InvalidEvent, "Invalid event.", False)
}

pub fn room_unavailable_fixture_preserves_requested_room_and_terminal_policy_test() {
  let assert Ok(domain.ServerError(error)) =
    protocol.decode_server_event(
      "{\"type\":\"error\",\"room_id\":\"default\",\"code\":\"room_unavailable\",\"message\":\"Room is unavailable. Reconnect to continue.\",\"recoverable\":false}",
    )

  assert error
    == domain.ErrorEvent(
      Some(domain.default_room_id),
      domain.RoomUnavailable,
      "Room is unavailable. Reconnect to continue.",
      False,
    )
}

pub fn every_documented_error_code_decodes_to_its_domain_variant_test() {
  let codes = [
    #("invalid_event", domain.InvalidEvent),
    #("join_required", domain.JoinRequired),
    #("already_joined", domain.AlreadyJoined),
    #("invalid_room_id", domain.InvalidRoomId),
    #("room_not_found", domain.RoomNotFound),
    #("room_mismatch", domain.RoomMismatch),
    #("room_unavailable", domain.RoomUnavailable),
    #("invalid_username", domain.InvalidUsername),
    #("invalid_message", domain.InvalidMessage),
    #("rate_limited", domain.RateLimited),
    #("room_full", domain.RoomFull),
  ]

  assert list.all(codes, fn(item) {
    let #(wire_code, expected_code) = item
    let payload =
      "{\"type\":\"error\",\"room_id\":null,\"code\":\""
      <> wire_code
      <> "\",\"message\":\"feedback\",\"recoverable\":true}"

    protocol.decode_server_event(payload)
    == Ok(
      domain.ServerError(domain.ErrorEvent(
        None,
        expected_code,
        "feedback",
        True,
      )),
    )
  })
}

pub fn unknown_future_server_events_are_safely_ignored_test() {
  assert protocol.decode_server_event(
      "{\"type\":\"typing_started\",\"room_id\":null,\"payload\":\"<script>alert(1)</script>\"}",
    )
    == Ok(domain.UnknownEvent)
}

pub fn xss_like_server_text_is_decoded_as_plain_data_test() {
  let payload =
    "{\"type\":\"user_joined\",\"room_id\":\"default\",\"user\":{\"connection_id\":\"connection-xss\",\"username\":\"<img src=x onerror=alert(1)>\"}}"
  let assert Ok(domain.UserJoined(_, domain.Presence(_, username))) =
    protocol.decode_server_event(payload)
  assert username == "<img src=x onerror=alert(1)>"
}

pub fn malformed_json_and_known_event_shapes_fail_safely_test() {
  let malformed = [
    "not json",
    "{\"room_id\":\"default\"}",
    "{\"type\":42,\"room_id\":\"default\"}",
    "{\"type\":\"room_state\"}",
    "{\"type\":\"room_state\",\"room_id\":null,\"self_id\":\"self\",\"users\":[],\"messages\":[]}",
    "{\"type\":\"user_joined\",\"room_id\":\"default\",\"user\":null}",
    "{\"type\":\"user_left\",\"room_id\":\"default\",\"connection_id\":42}",
    "{\"type\":\"message_sent\",\"room_id\":\"default\",\"message\":{\"message_id\":\"m\",\"sender_id\":\"c\",\"username\":\"Ada\",\"text\":\"Hi\"}}",
    "{\"type\":\"error\",\"room_id\":\"default\",\"code\":\"not_a_code\",\"message\":\"Nope\",\"recoverable\":true}",
    "{\"type\":\"error\",\"code\":\"invalid_event\",\"message\":\"Invalid event.\",\"recoverable\":false}",
    "{\"type\":\"error\",\"room_id\":42,\"code\":\"invalid_event\",\"message\":\"Invalid event.\",\"recoverable\":false}",
    "{\"type\":\"error\",\"room_id\":null,\"code\":\"invalid_event\",\"message\":\"Invalid event.\",\"recoverable\":\"false\"}",
  ]

  assert list.all(malformed, fn(payload) {
    protocol.decode_server_event(payload) == Error(domain.MalformedServerEvent)
  })
}

pub fn server_message_text_validation_rejects_controls_at_boundary_test() {
  let invalid_messages = [
    "Before\rAfter",
    "Before\u{2028}After",
    "Before\u{2029}After",
    "Before\u{0000}After",
  ]

  assert list.all(invalid_messages, fn(text) {
    let payload =
      "{\"type\":\"message_sent\",\"room_id\":\"default\",\"message\":{\"message_id\":\"m\",\"sender_id\":\"c\",\"username\":\"Ada\",\"text\":\""
      <> text
      <> "\",\"sent_at\":\"2026-08-08T20:15:00Z\"}}"
    protocol.decode_server_event(payload) == Error(domain.MalformedServerEvent)
  })
}
