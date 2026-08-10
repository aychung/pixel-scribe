import gleam/string
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
