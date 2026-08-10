import gleam/list
import gleam/option.{None}
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
