import gleam/list
import gleam/option.{None, Some}
import gleam/string
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/model
import pixel_scribe_frontend/update

pub fn initial_model_explicitly_owns_connection_state_test() {
  let state = model.initial()

  assert state.username_preference == ""
  assert state.username_input == ""
  assert state.phase == model.ChoosingUsername
  assert state.socket_generation == 0
  assert state.placement_seed == None
  assert state.room_snapshot == None
  assert state.draft == ""
  assert state.send_in_flight == None
  assert state.feedback == None
  assert state.connection_feedback == None
  assert state.reconnect_attempt == 0
  assert state.reconnect_timer == None
  assert state.rate_limit_until == None
  assert state.scene == model.Placeholder
}

pub fn every_connection_phase_can_be_constructed_test() {
  let self_id = domain.connection_id_from_string("self")
  let phases = [
    model.ChoosingUsername,
    model.Connecting(1, 2),
    model.AwaitingRoomState(1, 2),
    model.Joined(1, self_id),
    model.WaitingToReconnect(2, 3, 500),
    model.Blocked(model.ProtocolFailure),
    model.Blocked(model.OfficeUnavailable),
    model.Blocked(model.RoomFull),
  ]

  assert list.map(phases, phase_kind) == [0, 1, 2, 3, 4, 5, 5, 5]
}

pub fn nested_state_shapes_are_explicit_test() {
  let room_id = domain.default_room_id
  let self_id = domain.connection_id_from_string("self")
  let snapshot = model.RoomSnapshot(room_id, self_id, [], [], True)
  let in_flight = model.SendInFlight(3, "draft")
  let timer = model.ReconnectTimer(3, 8)

  assert snapshot.room_id == room_id
  assert snapshot.self_id == self_id
  assert snapshot.participants == []
  assert snapshot.messages == []
  assert snapshot.stale
  assert in_flight.generation == 3
  assert in_flight.text == "draft"
  assert timer.generation == 3
  assert timer.timer_id == 8
}

pub fn every_message_variant_is_a_trusted_constructor_test() {
  let messages = [
    update.UsernameInput("Ada"),
    update.SubmitUsername,
    update.DraftInput("Hello"),
    update.SubmitMessage,
    update.SocketOpened(1),
    update.SocketClosed(1, True),
    update.SocketError(1),
    update.ServerEvent(1, domain.UnknownEvent),
    update.ReconnectTimerFired(1, 8),
    update.RetryRequested,
    update.ReturnToUsername,
  ]

  assert list.map(messages, msg_kind) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
}

pub fn every_external_command_is_a_closed_trusted_value_test() {
  let commands = [
    update.OpenSocket(1),
    update.CloseSocket(1),
    update.SendSocketFrame(1, "{}"),
    update.WriteUsernamePreference("Ada"),
    update.ScheduleReconnect(1, 9, 500),
    update.CancelReconnect(1, 9),
    update.FocusUsername,
    update.FocusComposer,
    update.ScrollChatToEnd,
    update.RenderScene,
  ]

  assert list.map(commands, command_kind) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
}

pub fn local_input_remains_the_only_minimal_transition_test() {
  let initial = model.initial()
  let #(updated, commands) =
    update.transition(initial, update.UsernameInput("Ada"))

  assert updated.username_input == "Ada"
  assert commands == []
}

pub fn invalid_username_submit_stays_local_without_commands_test() {
  let invalid_inputs = ["", "   ", "Ada\n", string.repeat("a", 33)]

  assert list.all(invalid_inputs, fn(input) {
    let assert #(entered, []) =
      update.transition(model.initial(), update.UsernameInput(input))
    let #(submitted, commands) =
      update.transition(entered, update.SubmitUsername)

    submitted.phase == model.ChoosingUsername
    && submitted.username_input == input
    && submitted.feedback != None
    && commands == []
  })
}

pub fn valid_username_submit_normalizes_and_opens_one_generation_test() {
  let initial = model.initial()
  let initial =
    model.Model(..initial, socket_generation: 7, reconnect_attempt: 3)
  let assert #(entered, []) =
    update.transition(initial, update.UsernameInput("  Ada  "))
  let #(submitted, commands) = update.transition(entered, update.SubmitUsername)

  assert submitted.username_input == "Ada"
  assert submitted.username_preference == "Ada"
  assert submitted.socket_generation == 8
  assert submitted.phase == model.Connecting(8, 3)
  assert commands
    == [
      update.WriteUsernamePreference("Ada"),
      update.OpenSocket(8),
    ]
}

pub fn repeated_username_submit_while_connecting_is_ignored_test() {
  let assert #(entered, []) =
    update.transition(model.initial(), update.UsernameInput("Ada"))
  let #(connecting, first_commands) =
    update.transition(entered, update.SubmitUsername)
  let #(repeated, repeated_commands) =
    update.transition(connecting, update.SubmitUsername)

  assert first_commands
    == [update.WriteUsernamePreference("Ada"), update.OpenSocket(1)]
  assert repeated == connecting
  assert repeated_commands == []
}

pub fn matching_open_sends_exactly_one_join_frame_test() {
  let assert #(entered, []) =
    update.transition(model.initial(), update.UsernameInput("Ada"))
  let #(connecting, _) = update.transition(entered, update.SubmitUsername)
  let #(awaiting, commands) =
    update.transition(connecting, update.SocketOpened(1))

  assert awaiting.phase == model.AwaitingRoomState(1, 0)
  assert commands
    == [
      update.SendSocketFrame(
        1,
        "{\"type\":\"join_room\",\"room_id\":\"default\",\"username\":\"Ada\"}",
      ),
    ]

  let #(repeated, repeated_commands) =
    update.transition(awaiting, update.SocketOpened(1))
  assert repeated == awaiting
  assert repeated_commands == []
}

pub fn stale_or_wrong_phase_open_callbacks_are_ignored_test() {
  let assert #(entered, []) =
    update.transition(model.initial(), update.UsernameInput("Ada"))
  let #(connecting, _) = update.transition(entered, update.SubmitUsername)
  let #(stale, stale_commands) =
    update.transition(connecting, update.SocketOpened(2))
  assert stale == connecting
  assert stale_commands == []

  let #(wrong_phase, wrong_phase_commands) =
    update.transition(model.initial(), update.SocketOpened(0))
  assert wrong_phase == model.initial()
  assert wrong_phase_commands == []
}

pub fn only_matching_default_room_snapshot_enters_joined_test() {
  let self_id = domain.connection_id_from_string("self-1")
  let participant =
    domain.Presence(domain.connection_id_from_string("peer-1"), "Ada")
  let message =
    domain.ChatMessage(
      domain.message_id_from_string("message-1"),
      self_id,
      "Ada",
      "Hello",
      "2026-08-10T12:00:00Z",
    )

  let assert #(entered, []) =
    update.transition(model.initial(), update.UsernameInput("Ada"))
  let #(connecting, _) = update.transition(entered, update.SubmitUsername)
  let #(awaiting, _) = update.transition(connecting, update.SocketOpened(1))
  let waiting =
    model.Model(..awaiting, draft: "keep this draft", reconnect_attempt: 4)

  let #(wrong_generation, wrong_generation_commands) =
    update.transition(
      waiting,
      update.ServerEvent(
        2,
        domain.RoomState(domain.default_room_id, self_id, [participant], [
          message,
        ]),
      ),
    )
  assert wrong_generation == waiting
  assert wrong_generation_commands == []

  let other_room = domain.room_id_from_string("other")
  let #(wrong_room, wrong_room_commands) =
    update.transition(
      waiting,
      update.ServerEvent(
        1,
        domain.RoomState(other_room, self_id, [participant], [message]),
      ),
    )
  assert wrong_room == waiting
  assert wrong_room_commands == []

  let #(joined, commands) =
    update.transition(
      waiting,
      update.ServerEvent(
        1,
        domain.RoomState(domain.default_room_id, self_id, [participant], [
          message,
        ]),
      ),
    )
  assert joined.phase == model.Joined(1, self_id)
  assert joined.reconnect_attempt == 0
  assert joined.draft == "keep this draft"
  assert joined.room_snapshot
    == Some(model.RoomSnapshot(
      domain.default_room_id,
      self_id,
      [participant],
      [message],
      False,
    ))
  assert commands == []

  let #(ignored_after_join, ignored_commands) =
    update.transition(
      joined,
      update.ServerEvent(
        1,
        domain.RoomState(domain.default_room_id, self_id, [], []),
      ),
    )
  assert ignored_after_join == joined
  assert ignored_commands == []
}

fn phase_kind(phase: model.ConnectionPhase) -> Int {
  case phase {
    model.ChoosingUsername -> 0
    model.Connecting(_, _) -> 1
    model.AwaitingRoomState(_, _) -> 2
    model.Joined(_, _) -> 3
    model.WaitingToReconnect(_, _, _) -> 4
    model.Blocked(_) -> 5
  }
}

fn msg_kind(message: update.Msg) -> Int {
  case message {
    update.UsernameInput(_) -> 0
    update.SubmitUsername -> 1
    update.DraftInput(_) -> 2
    update.SubmitMessage -> 3
    update.SocketOpened(_) -> 4
    update.SocketClosed(_, _) -> 5
    update.SocketError(_) -> 6
    update.ServerEvent(_, _) -> 7
    update.ReconnectTimerFired(_, _) -> 8
    update.RetryRequested -> 9
    update.ReturnToUsername -> 10
  }
}

fn command_kind(command: update.Command) -> Int {
  case command {
    update.OpenSocket(_) -> 0
    update.CloseSocket(_) -> 1
    update.SendSocketFrame(_, _) -> 2
    update.WriteUsernamePreference(_) -> 3
    update.ScheduleReconnect(_, _, _) -> 4
    update.CancelReconnect(_, _) -> 5
    update.FocusUsername -> 6
    update.FocusComposer -> 7
    update.ScrollChatToEnd -> 8
    update.RenderScene -> 9
  }
}
