import gleam/option.{None, Some}
import pixel_scribe_backend/connection
import pixel_scribe_backend/domain
import pixel_scribe_backend/protocol
import pixel_scribe_backend/room

pub fn first_valid_join_resolves_the_requested_room_test() {
  let transition =
    connection.handle_client_frame(
      connection.AwaitingJoin,
      protocol.TextFrame(
        "{\"type\":\"join_room\",\"room_id\":\"default\",\"username\":\"Ada\"}",
      ),
    )

  let assert connection.Transition(
    connection.Joining(room_id),
    connection.ResolveRoom(requested_room_id, username),
  ) = transition
  assert room_id == domain.default_room_id
  assert requested_room_id == domain.default_room_id
  assert domain.username_to_string(username) == "Ada"
}

pub fn pre_join_messages_are_rejected_without_room_action_test() {
  let transition =
    connection.handle_client_frame(
      connection.AwaitingJoin,
      protocol.TextFrame(
        "{\"type\":\"send_message\",\"room_id\":\"default\",\"text\":\"Hello\"}",
      ),
    )

  let assert connection.Transition(
    connection.AwaitingJoin,
    connection.ReplyError(Some(room_id), protocol.JoinRequired, False),
  ) = transition
  assert room_id == domain.default_room_id
}

pub fn repeated_join_is_recoverable_and_does_not_replace_the_phase_test() {
  let assert Ok(room_id) = domain.new_room_id("default")
  let transition =
    connection.handle_client_frame(
      connection.Joining(room_id),
      protocol.TextFrame(
        "{\"type\":\"join_room\",\"room_id\":\"default\",\"username\":\"Grace\"}",
      ),
    )

  let assert connection.Transition(
    connection.Joining(current_room_id),
    connection.ReplyError(
      Some(requested_room_id),
      protocol.AlreadyJoined,
      False,
    ),
  ) = transition
  assert current_room_id == room_id
  assert requested_room_id == room_id
}

pub fn mismatched_room_messages_are_rejected_without_sending_test() {
  let assert Ok(room_id) = domain.new_room_id("default")
  let connection_id = domain.new_connection_id()
  let transition =
    connection.handle_client_frame(
      connection.Joined(room_id, connection_id),
      protocol.TextFrame(
        "{\"type\":\"send_message\",\"room_id\":\"other\",\"text\":\"Hello\"}",
      ),
    )

  let assert connection.Transition(
    connection.Joined(current_room_id, current_connection_id),
    connection.ReplyError(Some(requested_room_id), protocol.RoomMismatch, False),
  ) = transition
  assert current_room_id == room_id
  assert current_connection_id == connection_id
  let assert Ok(other_room_id) = domain.new_room_id("other")
  assert requested_room_id == other_room_id
}

pub fn same_room_messages_are_forwarded_to_the_room_test() {
  let assert Ok(room_id) = domain.new_room_id("default")
  let connection_id = domain.new_connection_id()
  let transition =
    connection.handle_client_frame(
      connection.Joined(room_id, connection_id),
      protocol.TextFrame(
        "{\"type\":\"send_message\",\"room_id\":\"default\",\"text\":\"Hello\"}",
      ),
    )

  let assert connection.Transition(
    connection.Joined(current_room_id, current_connection_id),
    connection.SendMessage(requested_room_id, requested_connection_id, text),
  ) = transition
  assert current_room_id == room_id
  assert current_connection_id == connection_id
  assert requested_room_id == room_id
  assert requested_connection_id == connection_id
  assert domain.message_text_to_string(text) == "Hello"
}

pub fn invalid_event_closes_but_invalid_message_stays_open_test() {
  let invalid_event =
    connection.handle_client_frame(
      connection.AwaitingJoin,
      protocol.TextFrame("not json"),
    )
  let assert connection.Transition(
    connection.AwaitingJoin,
    connection.ReplyError(None, protocol.InvalidEvent, True),
  ) = invalid_event

  let invalid_message =
    connection.handle_client_frame(
      connection.AwaitingJoin,
      protocol.TextFrame(
        "{\"type\":\"send_message\",\"room_id\":\"default\",\"text\":\"   \"}",
      ),
    )
  let assert connection.Transition(
    connection.AwaitingJoin,
    connection.ReplyError(Some(room_id), protocol.InvalidMessage, False),
  ) = invalid_message
  assert room_id == domain.default_room_id
  Nil
}

pub fn joined_room_events_become_client_events_and_state_test() {
  let connection_id = domain.new_connection_id()
  let assert Ok(username) = domain.new_username("Ada")
  let presence = domain.Presence(connection_id, username)
  let assert Ok(room_id) = domain.new_room_id("default")

  let joined =
    connection.handle_room_event(
      connection.Joining(room_id),
      room.Joined(room_id, connection_id, [presence], []),
    )
  let assert connection.Transition(
    connection.Joined(joined_room_id, joined_connection_id),
    connection.Emit(protocol.RoomState(
      snapshot_room_id,
      self_id,
      users,
      messages,
    )),
  ) = joined
  assert joined_room_id == room_id
  assert joined_connection_id == connection_id
  assert snapshot_room_id == room_id
  assert self_id == connection_id
  assert users == [presence]
  assert messages == []

  let joined_event =
    connection.handle_room_event(
      connection.Joined(room_id, connection_id),
      room.UserJoined(room_id, presence),
    )
  let assert connection.Transition(
    connection.Joined(_, _),
    connection.Emit(protocol.UserJoined(_, received_presence)),
  ) = joined_event
  assert received_presence == presence
}

pub fn joined_room_down_is_fatal_and_has_room_context_test() {
  let assert Ok(room_id) = domain.new_room_id("default")
  let transition =
    connection.handle_room_down(connection.Joined(
      room_id,
      domain.new_connection_id(),
    ))

  let assert connection.Transition(
    connection.Joined(_, _),
    connection.ReplyError(Some(error_room_id), protocol.RoomUnavailable, True),
  ) = transition
  assert error_room_id == room_id
}

pub fn awaiting_join_dead_room_sends_contextual_error_before_terminal_close_test() {
  let transition =
    connection.room_unavailable_transition(
      connection.AwaitingJoin,
      domain.default_room_id,
    )

  let assert connection.Transition(
    connection.AwaitingJoin,
    connection.ReplyError(Some(room_id), protocol.RoomUnavailable, True),
  ) = transition
  assert room_id == domain.default_room_id
  assert !protocol.error_is_recoverable(protocol.RoomUnavailable)
  assert protocol.encode_server_event(protocol.ErrorEvent(
      Some(room_id),
      protocol.RoomUnavailable,
    ))
    == "{\"type\":\"error\",\"room_id\":\"default\",\"code\":\"room_unavailable\",\"message\":\"Room is unavailable. Reconnect to continue.\",\"recoverable\":false}"
}

pub fn join_deadline_is_ten_seconds_test() {
  assert connection.join_deadline_ms == 10_000
}

pub fn awaiting_join_deadline_closes_without_emitting_an_error_test() {
  let assert connection.Transition(connection.AwaitingJoin, connection.Close) =
    connection.handle_join_deadline(connection.AwaitingJoin)
}

pub fn joining_join_deadline_closes_without_emitting_an_error_test() {
  let assert Ok(room_id) = domain.new_room_id("default")
  let assert connection.Transition(
    connection.Joining(current_room_id),
    connection.Close,
  ) = connection.handle_join_deadline(connection.Joining(room_id))
  assert current_room_id == room_id
}

pub fn joined_join_deadline_is_ignored_after_join_test() {
  let assert Ok(room_id) = domain.new_room_id("default")
  let phase = connection.Joined(room_id, domain.new_connection_id())
  let assert connection.Transition(current_phase, connection.Ignore) =
    connection.handle_join_deadline(phase)
  assert current_phase == phase
}
