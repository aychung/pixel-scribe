import gleam/list
import gleam/option.{None, Some}
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/model
import pixel_scribe_frontend/reconnect
import pixel_scribe_frontend/update

pub fn backoff_uses_capped_exponential_delay_and_jitter_bounds_test() {
  assert reconnect.base_delay_ms(0) == 500
  assert reconnect.base_delay_ms(1) == 1000
  assert reconnect.base_delay_ms(2) == 2000
  assert reconnect.base_delay_ms(3) == 4000
  assert reconnect.base_delay_ms(4) == 8000
  assert reconnect.base_delay_ms(5) == 16_000
  assert reconnect.base_delay_ms(6) == 30_000
  assert reconnect.base_delay_ms(99) == 30_000
  assert reconnect.base_delay_ms(-1) == 500

  assert reconnect.delay_ms(0, 0.0) == 375
  assert reconnect.delay_ms(0, 0.5) == 500
  assert reconnect.delay_ms(0, 1.0) == 625
  assert reconnect.delay_ms(2, 0.0) == 1500
  assert reconnect.delay_ms(2, 0.5) == 2000
  assert reconnect.delay_ms(6, 0.0) == 22_500
  assert reconnect.delay_ms(6, 0.5) == 30_000
  assert reconnect.delay_ms(6, 1.0) == 37_500
}

pub fn backoff_clamps_injected_random_values_to_documented_bounds_test() {
  assert reconnect.delay_ms(1, -1.0) == 750
  assert reconnect.delay_ms(1, 2.0) == 1250
}

pub fn unexpected_close_schedules_one_generation_safe_retry_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined =
    model.Model(
      ..joined_model(7, self_id),
      reconnect_attempt: 2,
      draft: "keep this",
      send_in_flight: Some(model.SendInFlight(7, "keep this")),
      rate_limit_until: Some(4000),
    )

  let #(waiting, commands) =
    update.transition(joined, update.SocketClosed(7, False, 0.0))

  assert waiting.phase == model.WaitingToReconnect(8, 3, 1500)
  assert waiting.socket_generation == 8
  assert waiting.reconnect_attempt == 3
  assert waiting.reconnect_timer == Some(model.ReconnectTimer(8, 8))
  assert waiting.draft == "keep this"
  assert waiting.send_in_flight == None
  assert snapshot_is_stale(waiting)
  assert waiting.rate_limit_until == None
  assert commands
    == [
      update.CancelRateLimit(7, 4000),
      update.ScheduleReconnect(8, 8, 1500),
    ]
}

pub fn socket_error_uses_injected_random_value_and_close_is_duplicate_safe_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined = model.Model(..joined_model(10, self_id), reconnect_attempt: 0)
  let #(waiting, commands) =
    update.transition(joined, update.SocketError(10, 1.0))

  assert waiting.phase == model.WaitingToReconnect(11, 1, 625)
  assert commands == [update.ScheduleReconnect(11, 11, 625)]

  let #(after_close, close_commands) =
    update.transition(waiting, update.SocketClosed(10, False, 0.0))
  assert after_close == waiting
  assert close_commands == []

  let #(after_error, error_commands) =
    update.transition(waiting, update.SocketError(10, 0.0))
  assert after_error == waiting
  assert error_commands == []
}

pub fn stale_timer_identity_and_generation_are_no_ops_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined = model.Model(..joined_model(20, self_id), reconnect_attempt: 1)
  let assert #(waiting, [_]) =
    update.transition(joined, update.SocketClosed(20, False, 0.5))

  let stale_callbacks = [
    update.ReconnectTimerFired(20, 21),
    update.ReconnectTimerFired(21, 20),
    update.ReconnectTimerFired(21, 22),
  ]

  let assert [first, second, third] = stale_callbacks
  let #(after_first, first_commands) = update.transition(waiting, first)
  let #(after_second, second_commands) = update.transition(waiting, second)
  let #(after_third, third_commands) = update.transition(waiting, third)
  assert after_first == waiting
  assert after_second == waiting
  assert after_third == waiting
  assert first_commands == []
  assert second_commands == []
  assert third_commands == []
}

pub fn matching_timer_opens_exact_next_generation_without_resetting_attempt_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined = model.Model(..joined_model(30, self_id), reconnect_attempt: 4)
  let assert #(waiting, [_]) =
    update.transition(joined, update.SocketClosed(30, False, 0.5))

  let assert model.WaitingToReconnect(next_generation, attempt, _) =
    waiting.phase
  let assert Some(timer) = waiting.reconnect_timer
  let #(connecting, commands) =
    update.transition(
      waiting,
      update.ReconnectTimerFired(timer.generation, timer.timer_id),
    )

  assert next_generation == 31
  assert connecting.phase == model.Connecting(next_generation, attempt)
  assert connecting.socket_generation == next_generation
  assert connecting.reconnect_attempt == attempt
  assert connecting.reconnect_timer == None
  assert commands == [update.OpenSocket(next_generation)]
}

pub fn manual_retry_cancels_timer_and_opens_without_replaying_draft_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined =
    model.Model(
      ..joined_model(40, self_id),
      reconnect_attempt: 2,
      draft: "do not replay",
    )
  let assert #(waiting, [_]) =
    update.transition(joined, update.SocketClosed(40, False, 0.5))
  let assert Some(timer) = waiting.reconnect_timer

  let #(connecting, commands) =
    update.transition(waiting, update.RetryRequested)

  assert connecting.phase == model.Connecting(41, 3)
  assert connecting.reconnect_attempt == 3
  assert connecting.draft == "do not replay"
  assert connecting.reconnect_timer == None
  assert commands
    == [
      update.CancelReconnect(timer.generation, timer.timer_id),
      update.OpenSocket(41),
    ]
}

pub fn deliberate_close_and_return_cancel_do_not_reconnect_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined =
    model.Model(
      ..joined_model(50, self_id),
      draft: "keep local draft",
      send_in_flight: Some(model.SendInFlight(50, "keep local draft")),
    )
  let #(closed, close_commands) =
    update.transition(joined, update.SocketClosed(50, True, 0.5))

  assert closed.phase == model.Joined(50, self_id)
  assert closed.draft == "keep local draft"
  assert closed.send_in_flight == None
  assert snapshot_is_stale(closed)
  assert close_commands == []

  let #(entry, return_commands) =
    update.transition(closed, update.ReturnToUsername)
  assert entry.phase == model.ChoosingUsername
  assert entry.reconnect_timer == None
  assert return_commands == [update.CloseSocket(50), update.FocusUsername]
  assert list_contains_reconnect_command(return_commands) == False
}

pub fn manual_retry_replaces_each_active_socket_phase_test() {
  let self_id = domain.connection_id_from_string("self")
  let phases = [
    model.Connecting(1, 2),
    model.AwaitingRoomState(1, 2),
    model.Joined(1, self_id),
  ]

  assert list.all(phases, fn(phase) {
    let state =
      model.Model(
        ..model.initial(),
        phase: phase,
        socket_generation: 1,
        reconnect_attempt: 2,
        room_snapshot: Some(model.RoomSnapshot(
          domain.default_room_id,
          self_id,
          [],
          [],
          False,
        )),
      )
    let #(updated, commands) = update.transition(state, update.RetryRequested)
    updated.phase == model.Connecting(2, 2)
    && updated.socket_generation == 2
    && updated.reconnect_attempt == 2
    && commands == [update.CloseSocket(1), update.OpenSocket(2)]
  })
}

pub fn room_unavailable_retry_replaces_socket_and_rejects_old_close_test() {
  let self_id = domain.connection_id_from_string("self")
  let state =
    model.Model(
      ..joined_model(70, self_id),
      reconnect_attempt: 3,
      draft: "preserve this",
      send_in_flight: Some(model.SendInFlight(70, "preserve this")),
    )
  let unavailable =
    update.ServerEvent(
      70,
      0,
      domain.ServerError(domain.ErrorEvent(
        Some(domain.default_room_id),
        domain.RoomUnavailable,
        "Room unavailable",
        False,
      )),
    )
  let #(stale, unavailable_commands) = update.transition(state, unavailable)
  assert unavailable_commands == []
  assert snapshot_is_stale(stale)
  assert stale.send_in_flight == None

  let #(connecting, retry_commands) =
    update.transition(stale, update.RetryRequested)
  assert connecting.phase == model.Connecting(71, 3)
  assert connecting.socket_generation == 71
  assert connecting.reconnect_attempt == 3
  assert connecting.draft == "preserve this"
  assert snapshot_is_stale(connecting)
  assert retry_commands == [update.CloseSocket(70), update.OpenSocket(71)]

  let #(after_old_close, old_close_commands) =
    update.transition(connecting, update.SocketClosed(70, False, 0.0))
  assert after_old_close == connecting
  assert old_close_commands == []
}

pub fn return_from_waiting_cancels_only_timer_and_preserves_draft_test() {
  let self_id = domain.connection_id_from_string("self")
  let state =
    model.Model(
      ..joined_model(80, self_id),
      reconnect_attempt: 1,
      draft: "keep on entry",
    )
  let assert #(waiting, [_]) =
    update.transition(state, update.SocketClosed(80, False, 0.5))
  let waiting =
    model.Model(
      ..waiting,
      feedback: Some("field feedback"),
      connection_feedback: Some("connection feedback"),
    )
  let assert Some(timer) = waiting.reconnect_timer

  let #(entry, commands) = update.transition(waiting, update.ReturnToUsername)
  assert entry.phase == model.ChoosingUsername
  assert entry.room_snapshot == None
  assert entry.draft == "keep on entry"
  assert entry.feedback == None
  assert entry.connection_feedback == None
  assert entry.reconnect_timer == None
  assert commands
    == [
      update.CancelReconnect(timer.generation, timer.timer_id),
      update.FocusUsername,
    ]
}

pub fn matching_room_state_only_resets_attempt_and_cancels_pending_timer_test() {
  let self_id = domain.connection_id_from_string("self")
  let awaiting =
    model.Model(
      ..model.initial(),
      username_preference: "Ada",
      username_input: "Ada",
      phase: model.AwaitingRoomState(60, 5),
      socket_generation: 60,
      reconnect_attempt: 5,
      reconnect_timer: Some(model.ReconnectTimer(60, 61)),
    )
  let room_state =
    update.ServerEvent(
      60,
      0,
      domain.RoomState(domain.default_room_id, self_id, [], []),
    )

  let #(joined, commands) = update.transition(awaiting, room_state)
  assert joined.phase == model.Joined(60, self_id)
  assert joined.reconnect_attempt == 0
  assert joined.reconnect_timer == None
  assert commands == [update.CancelReconnect(60, 61)]
}

pub fn socket_open_does_not_reset_backoff_attempt_test() {
  let model =
    model.Model(
      ..model.initial(),
      username_preference: "Ada",
      username_input: "Ada",
      phase: model.Connecting(70, 6),
      socket_generation: 70,
      reconnect_attempt: 6,
    )

  let #(awaiting, commands) = update.transition(model, update.SocketOpened(70))
  assert awaiting.phase == model.AwaitingRoomState(70, 6)
  assert awaiting.reconnect_attempt == 6
  assert commands != []
}

fn joined_model(generation: Int, self_id: domain.ConnectionId) -> model.Model {
  model.Model(
    ..model.initial(),
    phase: model.Joined(generation, self_id),
    socket_generation: generation,
    room_snapshot: Some(model.RoomSnapshot(
      domain.default_room_id,
      self_id,
      [],
      [],
      False,
    )),
  )
}

fn snapshot_is_stale(state: model.Model) -> Bool {
  case state.room_snapshot {
    Some(snapshot) -> snapshot.stale
    None -> False
  }
}

fn list_contains_reconnect_command(commands: List(update.Command)) -> Bool {
  case commands {
    [] -> False
    [update.ScheduleReconnect(_, _, _), ..] -> True
    [_, ..rest] -> list_contains_reconnect_command(rest)
  }
}
