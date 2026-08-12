import pixel_scribe_frontend/domain
import pixel_scribe_frontend/runtime
import pixel_scribe_frontend/socket
import pixel_scribe_frontend/update

pub fn websocket_url_uses_same_origin_for_http_test() {
  assert socket.websocket_url("http:", "localhost:8080")
    == "ws://localhost:8080/ws"
}

pub fn websocket_url_upgrades_https_to_wss_test() {
  assert socket.websocket_url("https:", "pixel.example")
    == "wss://pixel.example/ws"
}

pub fn websocket_url_uses_ws_for_non_https_protocols_test() {
  assert socket.websocket_url("file:", "pixel.example")
    == "ws://pixel.example/ws"
}

pub fn socket_message_ingress_decodes_unknown_events_without_payload_test() {
  let message =
    runtime.socket_fact_to_msg(socket.Message(
      12,
      345,
      "{\"type\":\"future_event\",\"secret\":\"discard\"}",
    ))

  assert message == update.ServerEvent(12, 345, domain.UnknownEvent)
}

pub fn socket_message_ingress_rejects_malformed_known_frames_test() {
  let message =
    runtime.socket_fact_to_msg(socket.Message(
      12,
      345,
      "{\"type\":\"room_state\",\"room_id\":\"default\"}",
    ))

  assert message == update.ServerDecodeFailed(12)
}

pub fn socket_message_ingress_rejects_malformed_raw_frames_test() {
  let message = runtime.socket_fact_to_msg(socket.Message(12, 345, "not json"))

  assert message == update.ServerDecodeFailed(12)
}

pub fn socket_non_text_frame_ingress_fails_closed_test() {
  assert runtime.socket_fact_to_msg(socket.NonTextFrame(12))
    == update.ServerDecodeFailed(12)
}

pub fn socket_lifecycle_facts_preserve_browser_boundary_values_test() {
  assert runtime.socket_fact_to_msg(socket.Opened(8)) == update.SocketOpened(8)
  assert runtime.socket_fact_to_msg(socket.Error(8, 0.25))
    == update.SocketError(8, 0.25)
  assert runtime.socket_fact_to_msg(socket.Closed(8, False, 0.75))
    == update.SocketClosed(8, False, 0.75)
}
