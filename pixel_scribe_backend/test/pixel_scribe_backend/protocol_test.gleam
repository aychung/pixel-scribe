import gleam/bit_array
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
      "{\"type\":\"send_message\",\"room_id\":\"default\",\"text\":\"Hello\\nworld\"}",
    ))
    == Error(protocol.InvalidMessageTextValue)
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
