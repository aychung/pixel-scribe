import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/dev/query
import lustre/dev/simulate
import lustre/effect
import lustre/element
import pixel_scribe_frontend/browser
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/model
import pixel_scribe_frontend/runtime
import pixel_scribe_frontend/update
import pixel_scribe_frontend/view

pub fn username_input_allows_32_graphemes_without_utf16_maxlength_test() {
  let username = string.repeat("😀", 32)
  let #(model, _) =
    update.transition(model.initial(), update.UsernameInput(username))
  let rendered = element.to_string(view.view(model))

  assert string.contains(rendered, username)
  assert !string.contains(rendered, "maxlength")
}

pub fn username_view_connects_the_label_to_the_native_input_test() {
  let rendered = element.to_string(view.view(model.initial()))

  assert string.contains(rendered, "for=\"username\"")
  assert string.contains(rendered, "id=\"username\"")
}

pub fn username_view_exposes_connecting_and_awaiting_status_test() {
  let assert #(entered, []) =
    update.transition(model.initial(), update.UsernameInput("Ada"))
  let #(connecting, _) = update.transition(entered, update.SubmitUsername)
  let connecting_rendered = element.to_string(view.view(connecting))
  assert string.contains(connecting_rendered, "Connecting to the office")

  let #(awaiting, _) = update.transition(connecting, update.SocketOpened(1))
  let awaiting_rendered = element.to_string(view.view(awaiting))
  assert string.contains(awaiting_rendered, "Waiting for the office snapshot")
}

pub fn username_view_exposes_recoverable_connection_feedback_test() {
  let assert #(entered, []) =
    update.transition(model.initial(), update.UsernameInput("Ada"))
  let #(connecting, _) = update.transition(entered, update.SubmitUsername)
  let #(awaiting, _) = update.transition(connecting, update.SocketOpened(1))
  let error =
    domain.ErrorEvent(
      Some(domain.default_room_id),
      domain.JoinRequired,
      "Join is required before using the office.",
      True,
    )
  let #(updated, _) =
    update.transition(
      awaiting,
      update.ServerEvent(1, 0, domain.ServerError(error)),
    )

  let rendered = element.to_string(view.view(updated))
  assert string.contains(rendered, "Join is required before using the office.")
  assert string.contains(rendered, "role=\"alert\"")
}

pub fn room_state_view_exposes_minimal_joined_status_test() {
  let self_id = domain.connection_id_from_string("self-1")
  let self_presence = domain.Presence(self_id, "Ada")
  let assert #(entered, []) =
    update.transition(model.initial(), update.UsernameInput("Ada"))
  let #(connecting, _) = update.transition(entered, update.SubmitUsername)
  let #(awaiting, _) = update.transition(connecting, update.SocketOpened(1))
  let #(joined, _) =
    update.transition(
      awaiting,
      update.ServerEvent(
        1,
        0,
        domain.RoomState(domain.default_room_id, self_id, [self_presence], []),
      ),
    )

  let rendered = element.to_string(view.view(joined))
  assert string.contains(rendered, "Joined the default office")
}

pub fn participant_list_is_keyed_by_connection_id_and_keeps_duplicate_labels_test() {
  let self_id = domain.connection_id_from_string("connection-self")
  let peer_id = domain.connection_id_from_string("connection-peer")
  let participants = [
    domain.Presence(self_id, "Riley"),
    domain.Presence(peer_id, "Riley"),
  ]
  let joined = joined_model(participants, self_id)
  let rendered = element.to_string(view.view(joined))

  assert string.contains(rendered, "data-lustre-key=\"connection-self\"")
  assert string.contains(rendered, "data-lustre-key=\"connection-peer\"")
  assert count_substring(rendered, "class=\"participant-item\"") == 2
  assert count_substring(
      rendered,
      "<span class=\"participant-name\">Riley</span>",
    )
    == 2
  assert count_substring(rendered, "class=\"participant-self\"") == 1
  assert string.contains(rendered, "role=\"list\"")
}

pub fn participant_ids_are_not_rendered_as_user_facing_labels_test() {
  let self_id = domain.connection_id_from_string("opaque-self-id")
  let peer_id = domain.connection_id_from_string("opaque-peer-id")
  let joined =
    joined_model(
      [
        domain.Presence(self_id, "Ada"),
        domain.Presence(peer_id, "Grace"),
      ],
      self_id,
    )
  let rendered = element.to_string(view.view(joined))

  assert !string.contains(
    rendered,
    "<span class=\"participant-name\">opaque-self-id",
  )
  assert !string.contains(
    rendered,
    "<span class=\"participant-name\">opaque-peer-id",
  )
  assert !string.contains(rendered, "aria-label=\"opaque-self-id\"")
  assert !string.contains(rendered, "aria-label=\"opaque-peer-id\"")
}

pub fn participant_labels_are_literal_and_preserve_the_list_structure_test() {
  let self_id = domain.connection_id_from_string("safe-self")
  let dangerous = "<img src=x onerror=alert(1)>"
  let long_label = string.repeat("L", 32)
  let joined =
    joined_model(
      [
        domain.Presence(self_id, dangerous),
        domain.Presence(
          domain.connection_id_from_string("safe-peer"),
          long_label,
        ),
      ],
      self_id,
    )
  let rendered = element.to_string(view.view(joined))

  assert string.contains(rendered, "&lt;img src=x onerror=alert(1)&gt;")
  assert !string.contains(rendered, "<img src=x onerror=alert(1)>")
  assert string.contains(rendered, long_label)
  assert count_substring(rendered, "class=\"participant-item\"") == 2
  assert string.contains(rendered, "role=\"list\"")
  assert string.contains(rendered, "role=\"log\"")
  assert string.contains(rendered, "role=\"status\"")
}

pub fn joined_workspace_exposes_empty_chat_and_enabled_composer_semantics_test() {
  let self_id = domain.connection_id_from_string("joined-self")
  let joined = joined_model([domain.Presence(self_id, "Ada")], self_id)
  let rendered = element.to_string(view.view(joined))

  assert string.contains(rendered, "Participants")
  assert string.contains(rendered, "1 participant")
  assert string.contains(rendered, "Messages")
  assert string.contains(rendered, "No messages yet.")
  assert string.contains(rendered, "Write a message")
  assert string.contains(rendered, "for=\"message-draft\"")
  assert string.contains(rendered, "aria-busy=\"false\"")
  assert string.contains(rendered, "aria-disabled=\"false\"")
  assert !string.contains(rendered, " disabled")
}

pub fn joined_workspace_describes_the_canvas_with_a_permanent_caption_test() {
  let self_id = domain.connection_id_from_string("canvas-self")
  let joined = joined_model([domain.Presence(self_id, "Ada")], self_id)
  let rendered = element.to_string(view.view(joined))

  assert string.contains(rendered, "Pixel-art office scene.")
  assert string.contains(rendered, "aria-describedby=\"canvas-fallback\"")
  assert !string.contains(rendered, "The office canvas will appear here.")
}

pub fn chat_log_renders_snapshot_messages_in_order_and_keys_by_message_id_test() {
  let self_id = domain.connection_id_from_string("chat-self")
  let messages = [
    domain.ChatMessage(
      domain.message_id_from_string("message-first"),
      self_id,
      "Ada",
      "First message",
      "2026-08-10T16:00:00Z",
    ),
    domain.ChatMessage(
      domain.message_id_from_string("message-second"),
      domain.connection_id_from_string("chat-peer"),
      "Grace",
      "Second message",
      "2026-08-10T16:01:00Z",
    ),
  ]
  let joined =
    joined_model_with_messages(
      [domain.Presence(self_id, "Ada")],
      self_id,
      messages,
    )
  let rendered = element.to_string(view.view(joined))

  assert string.contains(rendered, "data-lustre-key=\"message-first\"")
  assert string.contains(rendered, "data-lustre-key=\"message-second\"")
  assert string.contains(rendered, "id=\"chat-log\"")
  assert string.contains(rendered, "tabindex=\"0\"")
  let assert [_, after_first, ..] = string.split(rendered, "First message")
  assert string.contains(after_first, "Second message")
  assert count_substring(rendered, "class=\"chat-message\"") == 2
  assert !string.contains(rendered, "No messages yet.")
}

pub fn chat_log_marks_only_the_self_sender_and_keeps_duplicate_names_distinct_test() {
  let self_id = domain.connection_id_from_string("chat-self")
  let peer_id = domain.connection_id_from_string("chat-peer")
  let messages = [
    domain.ChatMessage(
      domain.message_id_from_string("self-message"),
      self_id,
      "Riley",
      "From me",
      "2026-08-10T16:00:00Z",
    ),
    domain.ChatMessage(
      domain.message_id_from_string("peer-message"),
      peer_id,
      "Riley",
      "From Riley too",
      "2026-08-10T16:01:00Z",
    ),
  ]
  let joined =
    joined_model_with_messages(
      [domain.Presence(self_id, "Riley"), domain.Presence(peer_id, "Riley")],
      self_id,
      messages,
    )
  let rendered = element.to_string(view.view(joined))

  assert count_substring(rendered, "class=\"message-sender\">Riley") == 2
  assert count_substring(rendered, "class=\"message-self\"") == 1
  assert string.contains(rendered, "(You)")
  assert string.contains(rendered, "From me")
  assert string.contains(rendered, "From Riley too")
}

pub fn chat_log_preserves_multiline_text_and_escapes_long_untrusted_values_test() {
  let self_id = domain.connection_id_from_string("chat-self")
  let long_text = string.repeat("L", 500)
  let message =
    domain.ChatMessage(
      domain.message_id_from_string("message-safe"),
      self_id,
      "<img src=x onerror=alert(1)>",
      "<script>alert(1)</script>\nSecond line\n" <> long_text,
      "2026-08-10T16:00:00Z",
    )
  let joined =
    joined_model_with_messages(
      [domain.Presence(self_id, "<img src=x onerror=alert(1)>")],
      self_id,
      [message],
    )
  let rendered = element.to_string(view.view(joined))

  assert string.contains(rendered, "&lt;img src=x onerror=alert(1)&gt;")
  assert string.contains(
    rendered,
    "<p class=\"message-text\">&lt;script&gt;alert(1)&lt;/script&gt;<br>Second line<br>",
  )
  assert count_substring(rendered, "<br>") == 2
  assert string.contains(rendered, long_text)
  assert !string.contains(rendered, "<script>alert(1)</script>")
  assert !string.contains(rendered, "<img src=x onerror=alert(1)>")
}

pub fn chat_log_uses_server_timestamp_and_temporary_history_copy_test() {
  let self_id = domain.connection_id_from_string("chat-self")
  let message =
    domain.ChatMessage(
      domain.message_id_from_string("message-time"),
      self_id,
      "Ada",
      "Timed message",
      "2026-08-10T16:00:00Z",
    )
  let joined =
    joined_model_with_messages([domain.Presence(self_id, "Ada")], self_id, [
      message,
    ])
  let rendered = element.to_string(view.view(joined))
  let local_timestamp = browser.format_timestamp_local("2026-08-10T16:00:00Z")

  assert string.contains(
    rendered,
    "<time class=\"message-time\" datetime=\"2026-08-10T16:00:00Z\">",
  )
  assert string.contains(rendered, local_timestamp)
  assert string.contains(rendered, "Messages are temporary and kept in memory")
  assert string.contains(rendered, "may disappear after a backend restart")
  assert !string.contains(rendered, "persist")
}

pub fn joined_workspace_exposes_busy_composer_semantics_test() {
  let self_id = domain.connection_id_from_string("joined-self")
  let joined = joined_model([domain.Presence(self_id, "Ada")], self_id)
  let #(drafted, _) = update.transition(joined, update.DraftInput("Hello"))
  let #(busy, _) = update.transition(drafted, update.SubmitMessage)
  let rendered = element.to_string(view.view(busy))

  assert string.contains(rendered, "aria-busy=\"true\"")
  assert string.contains(rendered, "aria-disabled=\"true\"")
  assert string.contains(rendered, " disabled")
  assert string.contains(rendered, "Sending…")
}

pub fn composer_input_event_controls_the_rendered_textarea_test() {
  let simulation =
    joined_simulation()
    |> simulate.input(
      on: query.element(matching: query.id("message-draft")),
      value: "Draft from the textarea",
    )

  let updated = simulate.model(simulation)
  let rendered = element.to_string(simulate.view(simulation))

  assert updated.draft == "Draft from the textarea"
  assert string.contains(rendered, "Draft from the textarea")
}

pub fn composer_enter_submits_when_not_shifted_or_composing_test() {
  let simulation =
    joined_simulation()
    |> simulate.input(
      on: query.element(matching: query.id("message-draft")),
      value: "Send this",
    )
    |> enter_key(False, False)

  let updated = simulate.model(simulation)

  assert updated.send_in_flight == Some(model.SendInFlight(1, "Send this"))
}

pub fn composer_shift_enter_does_not_submit_test() {
  let simulation =
    joined_simulation()
    |> simulate.input(
      on: query.element(matching: query.id("message-draft")),
      value: "Keep writing",
    )
    |> enter_key(True, False)

  let updated = simulate.model(simulation)

  assert updated.draft == "Keep writing"
  assert updated.send_in_flight == None
}

pub fn composer_composing_enter_does_not_submit_test() {
  let simulation =
    joined_simulation()
    |> simulate.input(
      on: query.element(matching: query.id("message-draft")),
      value: "Keep composing",
    )
    |> enter_key(False, True)

  let updated = simulate.model(simulation)

  assert updated.draft == "Keep composing"
  assert updated.send_in_flight == None
}

pub fn composer_invalid_input_stays_visible_with_inline_feedback_test() {
  let simulation =
    joined_simulation()
    |> simulate.input(
      on: query.element(matching: query.id("message-draft")),
      value: "\t",
    )
    |> enter_key(False, False)

  let updated = simulate.model(simulation)
  let rendered = element.to_string(simulate.view(simulation))

  assert updated.draft == "\t"
  assert updated.send_in_flight == None
  assert updated.feedback
    == Some("Message contains an unsupported control character.")
  assert string.contains(
    rendered,
    "Message contains an unsupported control character.",
  )
}

pub fn composer_oversized_frame_stays_visible_without_becoming_busy_test() {
  let text = string.repeat("👩‍👩‍👧‍👦", 500)
  let simulation =
    joined_simulation()
    |> simulate.input(
      on: query.element(matching: query.id("message-draft")),
      value: text,
    )
    |> enter_key(False, False)

  let updated = simulate.model(simulation)
  let rendered = element.to_string(simulate.view(simulation))

  assert updated.draft == text
  assert updated.send_in_flight == None
  assert updated.feedback == Some("Message is too large to send.")
  assert string.contains(rendered, "Message is too large to send.")
  assert string.contains(rendered, "aria-busy=\"false\"")
  assert string.contains(rendered, "aria-disabled=\"false\"")
}

pub fn stale_joined_workspace_disables_composer_and_exposes_recovery_status_test() {
  let self_id = domain.connection_id_from_string("joined-self")
  let joined = joined_model([domain.Presence(self_id, "Ada")], self_id)
  let #(recovering, _) =
    update.transition(joined, update.SocketClosed(1, False, 0.5))
  let rendered = element.to_string(view.view(recovering))

  assert string.contains(rendered, "Connection lost. Reconnecting")
  assert string.contains(rendered, "aria-busy=\"false\"")
  assert string.contains(rendered, "aria-disabled=\"true\"")
  assert string.contains(rendered, " disabled")
  assert string.contains(rendered, "Unavailable")
}

pub fn no_snapshot_recovery_offers_return_to_username_in_one_action_row_test() {
  let assert #(entered, []) =
    update.transition(model.initial(), update.UsernameInput("Ada"))
  let #(connecting, _) = update.transition(entered, update.SubmitUsername)
  let #(waiting, _) =
    update.transition(connecting, update.SocketClosed(1, False, 0.5))
  let waiting_rendered = element.to_string(view.view(waiting))

  assert string.contains(waiting_rendered, "Return to username")
  assert count_substring(waiting_rendered, "class=\"connection-actions\"") == 1

  let blocked_error =
    domain.ErrorEvent(None, domain.InvalidEvent, "Protocol error.", False)
  let #(blocked, _) =
    update.transition(
      connecting,
      update.ServerEvent(1, 0, domain.ServerError(blocked_error)),
    )
  let blocked_rendered = element.to_string(view.view(blocked))

  assert string.contains(blocked_rendered, "Return to username")
  assert count_substring(blocked_rendered, "class=\"connection-actions\"") == 1
}

fn joined_model(
  participants: List(domain.Presence),
  self_id: domain.ConnectionId,
) -> model.Model {
  joined_model_with_messages(participants, self_id, [])
}

fn joined_model_with_messages(
  participants: List(domain.Presence),
  self_id: domain.ConnectionId,
  messages: List(domain.ChatMessage),
) -> model.Model {
  let assert #(entered, []) =
    update.transition(model.initial(), update.UsernameInput("Ada"))
  let #(connecting, _) = update.transition(entered, update.SubmitUsername)
  let #(awaiting, _) = update.transition(connecting, update.SocketOpened(1))
  let #(joined, _) =
    update.transition(
      awaiting,
      update.ServerEvent(
        1,
        0,
        domain.RoomState(
          domain.default_room_id,
          self_id,
          participants,
          messages,
        ),
      ),
    )
  joined
}

fn count_substring(value: String, needle: String) -> Int {
  let pieces = string.split(value, needle)
  list.length(pieces) - 1
}

fn joined_simulation() {
  let self_id = domain.connection_id_from_string("joined-self")
  let self_presence = domain.Presence(self_id, "Ada")

  simulate.start(
    simulate.application(
      init: fn(_args: Nil) { #(model.initial(), effect.none()) },
      update: runtime.update,
      view: view.view,
    ),
    Nil,
  )
  |> simulate.message(update.UsernameInput("Ada"))
  |> simulate.message(update.SubmitUsername)
  |> simulate.message(update.SocketOpened(1))
  |> simulate.message(update.ServerEvent(
    1,
    0,
    domain.RoomState(domain.default_room_id, self_id, [self_presence], []),
  ))
}

fn enter_key(simulation, shift_key: Bool, is_composing: Bool) {
  simulate.event(
    simulation,
    on: query.element(matching: query.id("message-draft")),
    name: "keydown",
    data: [
      #("key", json.string("Enter")),
      #("shiftKey", json.bool(shift_key)),
      #("isComposing", json.bool(is_composing)),
    ],
  )
}
