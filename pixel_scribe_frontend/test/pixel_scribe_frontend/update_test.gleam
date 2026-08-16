import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import pixel_scribe_frontend/camera
import pixel_scribe_frontend/canvas
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/model
import pixel_scribe_frontend/runtime
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
  let participant = domain.Presence(self_id, "Ada")
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
        0,
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
        0,
        domain.RoomState(other_room, self_id, [participant], [message]),
      ),
    )
  assert wrong_room.phase == model.Blocked(model.ProtocolFailure)
  assert wrong_room.room_snapshot == waiting.room_snapshot
  assert wrong_room.send_in_flight == None
  assert wrong_room_commands == [update.CloseSocket(1)]

  let #(joined, commands) =
    update.transition(
      waiting,
      update.ServerEvent(
        1,
        0,
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
        0,
        domain.RoomState(domain.default_room_id, self_id, [participant], []),
      ),
    )
  assert ignored_after_join == joined
  assert ignored_commands == []
}

pub fn canvas_lifecycle_facts_do_not_emit_direct_draw_commands_test() {
  let self_id = domain.connection_id_from_string("canvas-self")
  let self_presence = domain.Presence(self_id, "Ada")
  let awaiting =
    model.Model(
      ..model.initial(),
      phase: model.AwaitingRoomState(2, 0),
      socket_generation: 2,
      placement_seed: Some(7),
    )

  let #(joined, join_commands) =
    update.transition(
      awaiting,
      update.ServerEvent(
        2,
        0,
        domain.RoomState(domain.default_room_id, self_id, [self_presence], []),
      ),
    )
  assert join_commands == []

  let #(ready, ready_commands) =
    update.transition(joined, update.CanvasReady(320, 240, 2.0))
  assert ready_commands == []
  assert runtime.scene_render_changed(joined.scene, ready.scene)

  let #(resized, resize_commands) =
    update.transition(ready, update.CanvasResized(640, 320, 2.0))
  assert resize_commands == []
  assert runtime.scene_render_changed(ready.scene, resized.scene)

  let #(failed, failure_commands) =
    update.transition(resized, update.CanvasFailed(canvas.AssetUnavailable))
  assert failure_commands == []
  assert failed.scene != resized.scene
  let assert model.Ready(_, _, _, resized_data, resized_camera, None) =
    resized.scene
  let assert model.Ready(_, _, _, failed_data, failed_camera, Some(_)) =
    failed.scene
  assert failed_data == resized_data
  assert failed_camera == resized_camera
  assert !runtime.scene_render_changed(resized.scene, failed.scene)
}

pub fn zoom_actions_update_only_the_camera_without_commands_test() {
  let self_id = domain.connection_id_from_string("zoom-self")
  let self_presence = domain.Presence(self_id, "Ada")
  let awaiting =
    model.Model(
      ..model.initial(),
      phase: model.AwaitingRoomState(2, 0),
      socket_generation: 2,
      placement_seed: Some(7),
    )
  let #(joined, _) =
    update.transition(
      awaiting,
      update.ServerEvent(
        2,
        0,
        domain.RoomState(domain.default_room_id, self_id, [self_presence], []),
      ),
    )
  let #(ready, _) = update.transition(joined, update.CanvasReady(320, 240, 2.0))

  let #(zoomed, zoom_commands) = update.transition(ready, update.ZoomIn)
  let assert model.Ready(_, _, _, _, Some(zoomed_camera), _) = zoomed.scene
  assert zoom_commands == []
  assert camera.zoom_level(zoomed_camera) == 2

  let #(reset, reset_commands) = update.transition(zoomed, update.ZoomReset)
  let assert model.Ready(_, _, _, _, Some(reset_camera), _) = reset.scene
  assert reset_commands == []
  assert camera.zoom_level(reset_camera) == 1
}

pub fn snapshot_missing_self_presence_fails_closed_test() {
  let self_id = domain.connection_id_from_string("self-1")
  let peer = domain.Presence(domain.connection_id_from_string("peer-1"), "Ada")
  let assert #(entered, []) =
    update.transition(model.initial(), update.UsernameInput("Ada"))
  let #(connecting, _) = update.transition(entered, update.SubmitUsername)
  let #(awaiting, _) = update.transition(connecting, update.SocketOpened(1))

  let #(blocked, commands) =
    update.transition(
      awaiting,
      update.ServerEvent(
        1,
        0,
        domain.RoomState(domain.default_room_id, self_id, [peer], []),
      ),
    )

  assert blocked.phase == model.Blocked(model.ProtocolFailure)
  assert blocked.connection_feedback == Some("Protocol error.")
  assert commands == [update.CloseSocket(1)]
}

pub fn snapshot_duplicate_self_presence_fails_closed_test() {
  let self_id = domain.connection_id_from_string("self-1")
  let self_presence = domain.Presence(self_id, "Ada")
  let assert #(entered, []) =
    update.transition(model.initial(), update.UsernameInput("Ada"))
  let #(connecting, _) = update.transition(entered, update.SubmitUsername)
  let #(awaiting, _) = update.transition(connecting, update.SocketOpened(1))

  let #(blocked, commands) =
    update.transition(
      awaiting,
      update.ServerEvent(
        1,
        0,
        domain.RoomState(
          domain.default_room_id,
          self_id,
          [self_presence, self_presence],
          [],
        ),
      ),
    )

  assert blocked.phase == model.Blocked(model.ProtocolFailure)
  assert commands == [update.CloseSocket(1)]
}

pub fn snapshot_duplicate_peer_presence_fails_closed_test() {
  let self_id = domain.connection_id_from_string("self-1")
  let self_presence = domain.Presence(self_id, "Ada")
  let peer_presence =
    domain.Presence(domain.connection_id_from_string("peer-1"), "Grace")
  let assert #(entered, []) =
    update.transition(model.initial(), update.UsernameInput("Ada"))
  let #(connecting, _) = update.transition(entered, update.SubmitUsername)
  let #(awaiting, _) = update.transition(connecting, update.SocketOpened(1))

  let #(blocked, commands) =
    update.transition(
      awaiting,
      update.ServerEvent(
        1,
        0,
        domain.RoomState(
          domain.default_room_id,
          self_id,
          [self_presence, peer_presence, peer_presence],
          [],
        ),
      ),
    )

  assert blocked.phase == model.Blocked(model.ProtocolFailure)
  assert commands == [update.CloseSocket(1)]
}

pub fn reconnect_snapshot_replaces_stale_snapshot_and_self_identity_test() {
  let old_self = domain.connection_id_from_string("old-self")
  let new_self = domain.connection_id_from_string("new-self")
  let old_user = domain.Presence(old_self, "Ada")
  let old_snapshot =
    model.RoomSnapshot(domain.default_room_id, old_self, [old_user], [], True)
  let replacement_user = domain.Presence(new_self, "Grace")
  let awaiting =
    model.Model(
      ..model.initial(),
      username_preference: "Ada",
      username_input: "Ada",
      phase: model.AwaitingRoomState(2, 3),
      socket_generation: 2,
      room_snapshot: Some(old_snapshot),
      draft: "preserve me",
    )

  let #(updated, commands) =
    update.transition(
      awaiting,
      update.ServerEvent(
        2,
        0,
        domain.RoomState(
          domain.default_room_id,
          new_self,
          [replacement_user],
          [],
        ),
      ),
    )

  assert updated.phase == model.Joined(2, new_self)
  assert updated.room_snapshot
    == Some(model.RoomSnapshot(
      domain.default_room_id,
      new_self,
      [replacement_user],
      [],
      False,
    ))
  assert updated.draft == "preserve me"
  assert updated.reconnect_attempt == 0
  assert commands == []
}

pub fn joined_presence_deltas_upsert_and_remove_by_connection_id_test() {
  let first_id = domain.connection_id_from_string("first")
  let second_id = domain.connection_id_from_string("second")
  let first = domain.Presence(first_id, "Same name")
  let second = domain.Presence(second_id, "Same name")
  let joined = joined_model(4, second_id, [first, second])

  let replacement = domain.Presence(first_id, "Renamed")
  let #(upserted, upsert_commands) =
    update.transition(
      joined,
      update.ServerEvent(
        4,
        0,
        domain.UserJoined(domain.default_room_id, replacement),
      ),
    )
  assert upsert_commands == []
  assert snapshot_participants(upserted) == [replacement, second]

  let #(removed, remove_commands) =
    update.transition(
      upserted,
      update.ServerEvent(
        4,
        0,
        domain.UserLeft(domain.default_room_id, first_id),
      ),
    )
  assert remove_commands == []
  assert snapshot_participants(removed) == [second]
}

pub fn current_generation_self_leave_fails_closed_test() {
  let self_id = domain.connection_id_from_string("self")
  let self_presence = domain.Presence(self_id, "Ada")
  let peer = domain.Presence(domain.connection_id_from_string("peer"), "Grace")
  let joined =
    model.Model(
      ..joined_model(36, self_id, [self_presence, peer]),
      draft: "preserve me",
      send_in_flight: Some(model.SendInFlight(36, "preserve me")),
    )

  let #(blocked, commands) =
    update.transition(
      joined,
      update.ServerEvent(
        36,
        0,
        domain.UserLeft(domain.default_room_id, self_id),
      ),
    )

  assert blocked.phase == model.Blocked(model.ProtocolFailure)
  assert snapshot_is_stale(blocked)
  assert blocked.draft == "preserve me"
  assert blocked.send_in_flight == None
  assert blocked.connection_feedback == Some("Protocol error.")
  assert commands == [update.CloseSocket(36)]
}

pub fn duplicate_join_keeps_one_presence_per_connection_id_test() {
  let first_id = domain.connection_id_from_string("first")
  let second_id = domain.connection_id_from_string("second")
  let first = domain.Presence(first_id, "First")
  let duplicate_first = domain.Presence(first_id, "Old duplicate")
  let second = domain.Presence(second_id, "Second")
  let replacement = domain.Presence(first_id, "Renamed")
  let joined = joined_model(28, first_id, [first, duplicate_first, second])

  let #(updated, commands) =
    update.transition(
      joined,
      update.ServerEvent(
        28,
        0,
        domain.UserJoined(domain.default_room_id, replacement),
      ),
    )

  assert snapshot_participants(updated) == [replacement, second]
  assert commands == []
}

pub fn unknown_leave_is_a_harmless_no_op_test() {
  let self_id = domain.connection_id_from_string("self")
  let peer =
    domain.Presence(domain.connection_id_from_string("peer"), "Same name")
  let unknown_id = domain.connection_id_from_string("unknown")
  let joined = joined_model(29, self_id, [peer])

  let #(updated, commands) =
    update.transition(
      joined,
      update.ServerEvent(
        29,
        0,
        domain.UserLeft(domain.default_room_id, unknown_id),
      ),
    )

  assert updated == joined
  assert commands == []
}

pub fn duplicate_usernames_remain_distinct_during_presence_deltas_test() {
  let first_id = domain.connection_id_from_string("first")
  let second_id = domain.connection_id_from_string("second")
  let first = domain.Presence(first_id, "Same name")
  let second = domain.Presence(second_id, "Same name")
  let joined = joined_model(5, second_id, [first, second])

  let #(updated, _) =
    update.transition(
      joined,
      update.ServerEvent(
        5,
        0,
        domain.UserJoined(domain.default_room_id, second),
      ),
    )

  assert snapshot_participants(updated) == [first, second]

  let #(removed, _) =
    update.transition(
      updated,
      update.ServerEvent(
        5,
        0,
        domain.UserLeft(domain.default_room_id, first_id),
      ),
    )
  assert snapshot_participants(removed) == [second]
}

pub fn room_snapshot_preserves_duplicate_usernames_by_connection_id_test() {
  let self_id = domain.connection_id_from_string("self")
  let peer_id = domain.connection_id_from_string("peer")
  let self_presence = domain.Presence(self_id, "Same name")
  let peer_presence = domain.Presence(peer_id, "Same name")
  let awaiting =
    model.Model(
      ..model.initial(),
      username_preference: "Same name",
      username_input: "Same name",
      phase: model.AwaitingRoomState(30, 0),
      socket_generation: 30,
    )

  let #(joined, commands) =
    update.transition(
      awaiting,
      update.ServerEvent(
        30,
        0,
        domain.RoomState(
          domain.default_room_id,
          self_id,
          [self_presence, peer_presence],
          [],
        ),
      ),
    )

  assert joined.phase == model.Joined(30, self_id)
  assert snapshot_participants(joined) == [self_presence, peer_presence]
  assert commands == []
}

pub fn current_generation_wrong_room_live_events_fail_closed_test() {
  let self_id = domain.connection_id_from_string("self")
  let peer_id = domain.connection_id_from_string("peer")
  let peer = domain.Presence(peer_id, "Peer")
  let other_room = domain.room_id_from_string("other")
  let incoming = message("incoming", peer_id, "from another room")
  let events = [
    domain.UserJoined(other_room, peer),
    domain.UserLeft(other_room, peer_id),
    domain.MessageSent(other_room, incoming),
  ]

  list.each(events, fn(event) {
    let joined =
      model.Model(
        ..joined_model(6, self_id, [peer]),
        draft: "preserve me",
        send_in_flight: Some(model.SendInFlight(6, "preserve me")),
      )
    let #(blocked, commands) =
      update.transition(joined, update.ServerEvent(6, 0, event))

    assert blocked.phase == model.Blocked(model.ProtocolFailure)
    assert snapshot_is_stale(blocked)
    assert blocked.draft == "preserve me"
    assert blocked.send_in_flight == None
    assert blocked.connection_feedback == Some("Protocol error.")
    assert commands == [update.CloseSocket(6)]
  })
}

pub fn current_generation_wrong_room_detection_is_phase_independent_test() {
  let self_id = domain.connection_id_from_string("self")
  let peer_id = domain.connection_id_from_string("peer")
  let peer = domain.Presence(peer_id, "Peer")
  let other_room = domain.room_id_from_string("other")
  let joined =
    model.Model(
      ..joined_model(7, self_id, [peer]),
      draft: "preserve me",
      send_in_flight: Some(model.SendInFlight(7, "preserve me")),
    )

  let #(blocked_snapshot, snapshot_commands) =
    update.transition(
      joined,
      update.ServerEvent(
        7,
        0,
        domain.RoomState(other_room, self_id, [peer], []),
      ),
    )
  assert blocked_snapshot.phase == model.Blocked(model.ProtocolFailure)
  assert snapshot_is_stale(blocked_snapshot)
  assert blocked_snapshot.send_in_flight == None
  assert snapshot_commands == [update.CloseSocket(7)]

  let awaiting =
    model.Model(
      ..model.initial(),
      phase: model.AwaitingRoomState(8, 0),
      socket_generation: 8,
      room_snapshot: Some(model.RoomSnapshot(
        domain.default_room_id,
        self_id,
        [peer],
        [],
        False,
      )),
      draft: "preserve me",
      send_in_flight: Some(model.SendInFlight(8, "preserve me")),
    )
  let events = [
    domain.UserJoined(other_room, peer),
    domain.UserLeft(other_room, peer_id),
    domain.MessageSent(other_room, message("incoming", peer_id, "elsewhere")),
  ]

  list.each(events, fn(event) {
    let #(blocked, commands) =
      update.transition(awaiting, update.ServerEvent(8, 0, event))
    assert blocked.phase == model.Blocked(model.ProtocolFailure)
    assert snapshot_is_stale(blocked)
    assert blocked.send_in_flight == None
    assert commands == [update.CloseSocket(8)]
  })
}

pub fn wrong_generation_presence_and_snapshot_callbacks_are_ignored_test() {
  let self_id = domain.connection_id_from_string("self")
  let peer_id = domain.connection_id_from_string("peer")
  let peer = domain.Presence(peer_id, "Peer")
  let joined = joined_model(6, self_id, [peer])
  let other_room = domain.room_id_from_string("other")

  let callbacks = [
    update.ServerEvent(
      5,
      0,
      domain.UserJoined(
        domain.default_room_id,
        domain.Presence(domain.connection_id_from_string("late"), "Late"),
      ),
    ),
    update.ServerEvent(5, 0, domain.UserLeft(domain.default_room_id, peer_id)),
    update.ServerEvent(
      5,
      0,
      domain.RoomState(
        domain.default_room_id,
        domain.connection_id_from_string("replacement-self"),
        [
          domain.Presence(
            domain.connection_id_from_string("replacement-self"),
            "Replacement",
          ),
        ],
        [],
      ),
    ),
    update.ServerEvent(
      5,
      0,
      domain.RoomState(
        other_room,
        domain.connection_id_from_string("replacement-self"),
        [
          domain.Presence(
            domain.connection_id_from_string("replacement-self"),
            "Replacement",
          ),
        ],
        [],
      ),
    ),
    update.ServerEvent(
      5,
      0,
      domain.UserJoined(
        other_room,
        domain.Presence(domain.connection_id_from_string("late-other"), "Late"),
      ),
    ),
    update.ServerEvent(5, 0, domain.UserLeft(other_room, peer_id)),
    update.ServerEvent(
      5,
      0,
      domain.MessageSent(other_room, message("late-message", peer_id, "late")),
    ),
  ]

  assert list.all(callbacks, fn(callback) {
    let #(updated, commands) = update.transition(joined, callback)
    updated == joined && commands == []
  })
}

pub fn draft_input_is_a_pure_controlled_value_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined = joined_model(7, self_id, [])

  let #(updated, commands) =
    update.transition(joined, update.DraftInput("  Keep this draft  "))

  assert updated.draft == "  Keep this draft  "
  assert updated.phase == model.Joined(7, self_id)
  assert commands == []
}

pub fn submit_message_sends_once_without_optimistic_append_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined = joined_model(8, self_id, [])
  let assert #(with_draft, []) =
    update.transition(joined, update.DraftInput("  Hello  "))

  let #(submitted, commands) =
    update.transition(with_draft, update.SubmitMessage)

  assert submitted.draft == "Hello"
  assert submitted.send_in_flight == Some(model.SendInFlight(8, "Hello"))
  assert snapshot_messages(submitted) == []
  assert commands
    == [
      update.SendSocketFrame(
        8,
        "{\"type\":\"send_message\",\"room_id\":\"default\",\"text\":\"Hello\"}",
      ),
    ]
}

pub fn repeated_submit_while_send_is_in_flight_is_ignored_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined = joined_model(9, self_id, [])
  let assert #(with_draft, []) =
    update.transition(joined, update.DraftInput("Hello"))
  let #(submitted, first_commands) =
    update.transition(with_draft, update.SubmitMessage)

  let #(repeated, repeated_commands) =
    update.transition(submitted, update.SubmitMessage)

  assert first_commands != []
  assert repeated == submitted
  assert repeated_commands == []
}

pub fn invalid_submit_stays_local_without_a_send_command_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined = joined_model(10, self_id, [])
  let invalid = "\t"
  let assert #(with_draft, []) =
    update.transition(joined, update.DraftInput(invalid))

  let #(submitted, commands) =
    update.transition(with_draft, update.SubmitMessage)

  assert submitted.draft == invalid
  assert submitted.send_in_flight == None
  assert submitted.phase == model.Joined(10, self_id)
  assert submitted.feedback != None
  assert commands == []
}

pub fn peer_echo_appends_but_keeps_draft_and_pending_send_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined = joined_model(11, self_id, [])
  let sending =
    model.Model(
      ..joined,
      draft: "mine",
      send_in_flight: Some(model.SendInFlight(11, "mine")),
    )
  let peer_id = domain.connection_id_from_string("peer")
  let peer_message = message("peer-message", peer_id, "from peer")

  let #(updated, commands) =
    update.transition(
      sending,
      update.ServerEvent(
        11,
        0,
        domain.MessageSent(domain.default_room_id, peer_message),
      ),
    )

  assert snapshot_messages(updated) == [peer_message]
  assert updated.draft == "mine"
  assert updated.send_in_flight == Some(model.SendInFlight(11, "mine"))
  assert commands == []
}

pub fn unique_accepted_self_message_scrolls_even_when_reader_was_not_near_bottom_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined = joined_model(31, self_id, [])
  let accepted = message("self-message", self_id, "accepted")

  let #(updated, commands) =
    update.transition(
      joined,
      update.AcceptedMessage(31, domain.default_room_id, accepted, False),
    )

  assert snapshot_messages(updated) == [accepted]
  assert commands == [update.ScrollChatToEnd]
}

pub fn unique_accepted_peer_message_scrolls_when_reader_was_near_bottom_test() {
  let self_id = domain.connection_id_from_string("self")
  let peer_id = domain.connection_id_from_string("peer")
  let joined = joined_model(32, self_id, [])
  let accepted = message("peer-message", peer_id, "accepted")

  let #(updated, commands) =
    update.transition(
      joined,
      update.AcceptedMessage(32, domain.default_room_id, accepted, True),
    )

  assert snapshot_messages(updated) == [accepted]
  assert commands == [update.ScrollChatToEnd]
}

pub fn unique_accepted_peer_message_preserves_older_reader_position_test() {
  let self_id = domain.connection_id_from_string("self")
  let peer_id = domain.connection_id_from_string("peer")
  let joined = joined_model(33, self_id, [])
  let accepted = message("peer-message", peer_id, "accepted")

  let #(updated, commands) =
    update.transition(
      joined,
      update.AcceptedMessage(33, domain.default_room_id, accepted, False),
    )

  assert snapshot_messages(updated) == [accepted]
  assert commands == []
}

pub fn duplicate_accepted_message_never_scrolls_test() {
  let self_id = domain.connection_id_from_string("self")
  let accepted = message("duplicate", self_id, "first")
  let joined =
    model.Model(
      ..joined_model(34, self_id, []),
      room_snapshot: Some(model.RoomSnapshot(
        domain.default_room_id,
        self_id,
        [],
        [accepted],
        False,
      )),
    )

  let #(updated, commands) =
    update.transition(
      joined,
      update.AcceptedMessage(
        34,
        domain.default_room_id,
        message("duplicate", self_id, "different body"),
        True,
      ),
    )

  assert updated == joined
  assert commands == []
}

pub fn stale_generation_and_wrong_room_accepted_messages_never_scroll_test() {
  let self_id = domain.connection_id_from_string("self")
  let peer_id = domain.connection_id_from_string("peer")
  let joined = joined_model(35, self_id, [])
  let accepted = message("stale", self_id, "accepted")
  let other_room = domain.room_id_from_string("other")

  let #(stale, stale_commands) =
    update.transition(
      joined,
      update.AcceptedMessage(34, domain.default_room_id, accepted, True),
    )
  let #(wrong_room, wrong_room_commands) =
    update.transition(
      joined,
      update.AcceptedMessage(
        35,
        other_room,
        message("wrong-room", peer_id, "elsewhere"),
        True,
      ),
    )

  assert stale == joined
  assert stale_commands == []
  assert wrong_room.phase == model.Blocked(model.ProtocolFailure)
  assert snapshot_is_stale(wrong_room)
  assert wrong_room.send_in_flight == None
  assert wrong_room.connection_feedback == Some("Protocol error.")
  assert wrong_room_commands == [update.CloseSocket(35)]
}

pub fn matching_self_echo_appends_and_clears_only_matching_draft_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined = joined_model(12, self_id, [])
  let sending =
    model.Model(
      ..joined,
      draft: "mine",
      send_in_flight: Some(model.SendInFlight(12, "mine")),
    )
  let accepted = message("self-message", self_id, "mine")

  let #(updated, commands) =
    update.transition(
      sending,
      update.ServerEvent(
        12,
        0,
        domain.MessageSent(domain.default_room_id, accepted),
      ),
    )

  assert snapshot_messages(updated) == [accepted]
  assert updated.draft == ""
  assert updated.send_in_flight == None
  assert commands == [update.ScrollChatToEnd]
}

pub fn self_echo_keeps_a_newer_current_draft_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined = joined_model(13, self_id, [])
  let sending =
    model.Model(
      ..joined,
      draft: "first",
      send_in_flight: Some(model.SendInFlight(13, "first")),
    )
  let assert #(edited, []) =
    update.transition(sending, update.DraftInput("second"))
  let accepted = message("self-message-2", self_id, "first")

  let #(updated, commands) =
    update.transition(
      edited,
      update.ServerEvent(
        13,
        0,
        domain.MessageSent(domain.default_room_id, accepted),
      ),
    )

  assert snapshot_messages(updated) == [accepted]
  assert updated.draft == "second"
  assert updated.send_in_flight == None
  assert commands == [update.ScrollChatToEnd]
}

pub fn duplicate_message_ids_are_no_op_and_snapshot_history_is_latest_50_test() {
  let self_id = domain.connection_id_from_string("self")
  let initial_messages = numbered_messages(1, 50, self_id)
  let joined =
    model.Model(
      ..joined_model(14, self_id, []),
      room_snapshot: Some(model.RoomSnapshot(
        domain.default_room_id,
        self_id,
        [],
        initial_messages,
        False,
      )),
    )
  let new_message = message("message-51", self_id, "newest")
  let assert #(with_new, [update.ScrollChatToEnd]) =
    update.transition(
      joined,
      update.ServerEvent(
        14,
        0,
        domain.MessageSent(domain.default_room_id, new_message),
      ),
    )

  assert list.length(snapshot_messages(with_new)) == 50
  assert list.first(snapshot_messages(with_new))
    == Ok(message("message-2", self_id, "message 2"))
  assert list.last(snapshot_messages(with_new)) == Ok(new_message)

  let duplicate = message("message-51", self_id, "different body")
  let #(unchanged, commands) =
    update.transition(
      with_new,
      update.ServerEvent(
        14,
        0,
        domain.MessageSent(domain.default_room_id, duplicate),
      ),
    )

  assert unchanged == with_new
  assert commands == []
}

pub fn room_state_snapshot_deduplicates_before_latest_50_bound_test() {
  let self_id = domain.connection_id_from_string("snapshot-self")
  let awaiting =
    model.Model(
      ..model.initial(),
      phase: model.AwaitingRoomState(17, 0),
      socket_generation: 17,
    )
  let messages_with_duplicate =
    list.append(numbered_messages(1, 51, self_id), [
      message("message-1", self_id, "duplicate after original"),
    ])
  let self_presence = domain.Presence(self_id, "Snapshot self")

  let #(joined, commands) =
    update.transition(
      awaiting,
      update.ServerEvent(
        17,
        0,
        domain.RoomState(
          domain.default_room_id,
          self_id,
          [self_presence],
          messages_with_duplicate,
        ),
      ),
    )

  assert list.length(snapshot_messages(joined)) == 50
  assert list.first(snapshot_messages(joined))
    == Ok(message("message-2", self_id, "message 2"))
  assert list.last(snapshot_messages(joined))
    == Ok(message("message-51", self_id, "message 51"))
  assert commands == []
}

pub fn stale_generation_and_nonmatching_self_echo_do_not_clear_pending_send_test() {
  let self_id = domain.connection_id_from_string("echo-self")
  let joined = joined_model(18, self_id, [])
  let sending =
    model.Model(
      ..joined,
      draft: "mine",
      send_in_flight: Some(model.SendInFlight(18, "mine")),
    )
  let stale_message = message("stale-message", self_id, "mine")
  let #(after_stale, stale_commands) =
    update.transition(
      sending,
      update.ServerEvent(
        17,
        0,
        domain.MessageSent(domain.default_room_id, stale_message),
      ),
    )

  assert after_stale == sending
  assert stale_commands == []

  let nonmatching_message =
    message("different-self-message", self_id, "not mine")
  let #(after_nonmatching, nonmatching_commands) =
    update.transition(
      sending,
      update.ServerEvent(
        18,
        0,
        domain.MessageSent(domain.default_room_id, nonmatching_message),
      ),
    )

  assert snapshot_messages(after_nonmatching) == [nonmatching_message]
  assert after_nonmatching.draft == "mine"
  assert after_nonmatching.send_in_flight
    == Some(model.SendInFlight(18, "mine"))
  assert nonmatching_commands == [update.ScrollChatToEnd]
}

pub fn submit_message_requires_matching_joined_snapshot_test() {
  let self_id = domain.connection_id_from_string("joined-self")
  let missing_snapshot =
    model.Model(
      ..model.initial(),
      phase: model.Joined(19, self_id),
      socket_generation: 19,
      draft: "Hello",
    )
  let wrong_room =
    model.Model(
      ..missing_snapshot,
      room_snapshot: Some(model.RoomSnapshot(
        domain.room_id_from_string("other"),
        self_id,
        [],
        [],
        False,
      )),
    )
  let wrong_self =
    model.Model(
      ..missing_snapshot,
      room_snapshot: Some(model.RoomSnapshot(
        domain.default_room_id,
        domain.connection_id_from_string("different-self"),
        [],
        [],
        False,
      )),
    )
  let stale_snapshot =
    model.Model(
      ..missing_snapshot,
      room_snapshot: Some(model.RoomSnapshot(
        domain.default_room_id,
        self_id,
        [],
        [],
        True,
      )),
    )

  assert list.all(
    [missing_snapshot, wrong_room, wrong_self, stale_snapshot],
    fn(state) {
      let #(updated, commands) = update.transition(state, update.SubmitMessage)
      updated == state && commands == []
    },
  )
}

pub fn matching_disconnect_enters_reconnect_and_preserves_draft_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined = joined_model(15, self_id, [])
  let sending =
    model.Model(
      ..joined,
      draft: "keep me",
      send_in_flight: Some(model.SendInFlight(15, "keep me")),
    )

  let #(updated, commands) =
    update.transition(sending, update.SocketClosed(15, False, 0.5))

  assert updated.phase == model.WaitingToReconnect(16, 1, 500)
  assert updated.socket_generation == 16
  assert updated.draft == "keep me"
  assert updated.send_in_flight == None
  assert snapshot_is_stale(updated)
  assert commands == [update.ScheduleReconnect(16, 16, 500)]
}

pub fn stale_disconnect_does_not_clear_replacement_send_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined =
    model.Model(
      ..joined_model(16, self_id, []),
      draft: "keep replacement",
      send_in_flight: Some(model.SendInFlight(16, "keep replacement")),
    )

  let #(updated, commands) =
    update.transition(joined, update.SocketClosed(15, False, 0.5))

  assert updated == joined
  assert commands == []
}

pub fn active_phase_error_matrix_has_explicit_outcomes_test() {
  let self_id = domain.connection_id_from_string("self")
  let connecting = model.Connecting(1, 0)
  let awaiting = model.AwaitingRoomState(1, 0)
  let joined = model.Joined(1, self_id)
  let other_room = domain.room_id_from_string("other")
  let cases = [
    #(connecting, domain.InvalidEvent, None, True),
    #(connecting, domain.InvalidEvent, Some(domain.default_room_id), True),
    #(awaiting, domain.JoinRequired, Some(domain.default_room_id), False),
    #(joined, domain.JoinRequired, Some(domain.default_room_id), True),
    #(joined, domain.AlreadyJoined, Some(domain.default_room_id), False),
    #(connecting, domain.AlreadyJoined, Some(domain.default_room_id), True),
    #(connecting, domain.InvalidRoomId, None, False),
    #(connecting, domain.InvalidRoomId, Some(domain.default_room_id), True),
    #(awaiting, domain.RoomNotFound, Some(domain.default_room_id), False),
    #(joined, domain.RoomNotFound, Some(domain.default_room_id), True),
    #(joined, domain.RoomMismatch, Some(other_room), False),
    #(joined, domain.RoomMismatch, Some(domain.default_room_id), True),
    #(joined, domain.RoomUnavailable, Some(domain.default_room_id), False),
    #(joined, domain.RoomUnavailable, None, True),
    #(connecting, domain.InvalidUsername, Some(domain.default_room_id), False),
    #(connecting, domain.InvalidUsername, None, True),
    #(joined, domain.InvalidMessage, Some(domain.default_room_id), False),
    #(awaiting, domain.InvalidMessage, None, True),
    #(joined, domain.RateLimited, Some(domain.default_room_id), False),
    #(awaiting, domain.RateLimited, Some(domain.default_room_id), True),
    #(awaiting, domain.RoomFull, Some(domain.default_room_id), False),
    #(joined, domain.RoomFull, Some(domain.default_room_id), True),
  ]

  list.each(cases, fn(item) {
    let #(phase, code, room_id, expect_protocol_failure) = item
    let state = model_for_phase(phase)
    let event =
      domain.ServerError(domain.ErrorEvent(
        room_id,
        code,
        "server feedback",
        expected_recoverability(code),
      ))
    let #(updated, commands) =
      update.transition(state, update.ServerEvent(1, 4000, event))

    case expect_protocol_failure {
      True -> {
        assert updated.phase == model.Blocked(model.ProtocolFailure)
        assert commands == [update.CloseSocket(1)]
      }
      False -> {
        assert updated.phase != model.Blocked(model.ProtocolFailure)
      }
    }
  })
}

pub fn error_recoverability_mismatch_fails_closed_without_loop_test() {
  let codes = [
    #(domain.InvalidEvent, True),
    #(domain.RoomUnavailable, True),
    #(domain.RoomFull, True),
    #(domain.JoinRequired, False),
    #(domain.AlreadyJoined, False),
    #(domain.InvalidRoomId, False),
    #(domain.RoomNotFound, False),
    #(domain.RoomMismatch, False),
    #(domain.InvalidUsername, False),
    #(domain.InvalidMessage, False),
    #(domain.RateLimited, False),
  ]

  list.each(codes, fn(item) {
    let #(code, recoverable) = item
    let state =
      model_for_phase(model.Joined(1, domain.connection_id_from_string("self")))
    let #(blocked, commands) =
      update.transition(
        state,
        update.ServerEvent(
          1,
          4000,
          domain.ServerError(error_event_with_recoverability(code, recoverable)),
        ),
      )
    assert blocked.phase == model.Blocked(model.ProtocolFailure)
    assert commands == [update.CloseSocket(1)]

    let #(unchanged, late_commands) =
      update.transition(
        blocked,
        update.ServerEvent(1, 4000, domain.ServerError(error_event(code))),
      )
    assert unchanged == blocked
    assert late_commands == []
  })
}

pub fn rate_limit_deadline_is_generation_and_deadline_safe_test() {
  let self_id = domain.connection_id_from_string("self")
  let joined =
    model.Model(
      ..joined_model(20, self_id, []),
      draft: "keep me",
      send_in_flight: Some(model.SendInFlight(20, "keep me")),
    )
  let #(limited, commands) =
    update.transition(
      joined,
      update.ServerEvent(
        20,
        4000,
        domain.ServerError(error_event(domain.RateLimited)),
      ),
    )

  assert limited.rate_limit_until == Some(5000)
  assert limited.draft == "keep me"
  assert limited.send_in_flight == None
  assert commands == [update.ScheduleRateLimit(20, 5000, 1000)]

  let #(blocked_send, blocked_commands) =
    update.transition(limited, update.SubmitMessage)
  assert blocked_send == limited
  assert blocked_commands == []

  let #(stale_timer, stale_commands) =
    update.transition(limited, update.RateLimitTimerFired(19, 5000))
  assert stale_timer == limited
  assert stale_commands == []

  let #(wrong_deadline, wrong_deadline_commands) =
    update.transition(limited, update.RateLimitTimerFired(20, 5001))
  assert wrong_deadline == limited
  assert wrong_deadline_commands == []

  let #(available, available_commands) =
    update.transition(limited, update.RateLimitTimerFired(20, 5000))
  assert available.rate_limit_until == None
  assert available_commands == []

  let #(closed, close_commands) =
    update.transition(limited, update.SocketClosed(20, False, 0.5))
  assert closed.rate_limit_until == None
  assert close_commands
    == [
      update.CancelRateLimit(20, 5000),
      update.ScheduleReconnect(21, 21, 500),
    ]
}

pub fn terminal_error_close_callbacks_are_no_ops_test() {
  let state =
    model.Model(
      ..model_for_phase(model.AwaitingRoomState(21, 0)),
      rate_limit_until: Some(5000),
    )
  let #(blocked, close_commands) =
    update.transition(
      state,
      update.ServerEvent(
        21,
        4000,
        domain.ServerError(error_event(domain.RoomFull)),
      ),
    )
  assert blocked.phase == model.Blocked(model.RoomFull)
  assert close_commands
    == [update.CloseSocket(21), update.CancelRateLimit(21, 5000)]

  let #(after_close, callbacks) =
    update.transition(blocked, update.SocketClosed(21, False, 0.5))
  assert after_close == blocked
  assert callbacks == []
}

pub fn username_error_returns_to_entry_without_losing_draft_test() {
  let self_id = domain.connection_id_from_string("self")
  let state =
    model.Model(
      ..joined_model(22, self_id, []),
      username_preference: "Ada",
      username_input: "Ada",
      draft: "keep this",
      send_in_flight: Some(model.SendInFlight(22, "keep this")),
    )
  let #(updated, commands) =
    update.transition(
      state,
      update.ServerEvent(
        22,
        4000,
        domain.ServerError(error_event(domain.InvalidUsername)),
      ),
    )

  assert updated.phase == model.ChoosingUsername
  assert updated.username_preference == "Ada"
  assert updated.username_input == "Ada"
  assert updated.draft == "keep this"
  assert updated.send_in_flight == None
  assert updated.feedback == Some("server feedback")
  assert commands == [update.CloseSocket(22), update.FocusUsername]
}

pub fn awaiting_join_required_disables_chat_without_a_resend_loop_test() {
  let self_id = domain.connection_id_from_string("self")
  let state =
    model.Model(
      ..model_for_phase(model.AwaitingRoomState(23, 0)),
      draft: "keep this",
      room_snapshot: Some(model.RoomSnapshot(
        domain.default_room_id,
        self_id,
        [],
        [],
        False,
      )),
    )
  let #(updated, commands) =
    update.transition(
      state,
      update.ServerEvent(
        23,
        4000,
        domain.ServerError(error_event(domain.JoinRequired)),
      ),
    )

  assert updated.phase == model.AwaitingRoomState(23, 0)
  assert updated.draft == "keep this"
  assert updated.send_in_flight == None
  assert updated.room_snapshot == state.room_snapshot
  assert commands == []

  let #(still_disabled, retry_commands) =
    update.transition(updated, update.SubmitMessage)
  assert still_disabled == updated
  assert retry_commands == []
}

pub fn room_unavailable_keeps_phase_for_the_close_reconnect_handoff_test() {
  let self_id = domain.connection_id_from_string("self")
  let state =
    model.Model(
      ..joined_model(24, self_id, []),
      draft: "keep this",
      send_in_flight: Some(model.SendInFlight(24, "keep this")),
    )
  let #(updated, commands) =
    update.transition(
      state,
      update.ServerEvent(
        24,
        4000,
        domain.ServerError(error_event(domain.RoomUnavailable)),
      ),
    )

  assert updated.phase == model.Joined(24, self_id)
  assert updated.draft == "keep this"
  assert updated.send_in_flight == None
  assert snapshot_is_stale(updated)
  assert commands == []
}

pub fn joined_error_table_preserves_draft_and_routes_feedback_test() {
  let self_id = domain.connection_id_from_string("self")
  let cases = [
    #(domain.InvalidUsername, 0, False, True, False),
    #(domain.InvalidMessage, 3, False, True, False),
    #(domain.RateLimited, 3, False, True, False),
    #(domain.JoinRequired, 5, False, False, True),
    #(domain.AlreadyJoined, 3, True, False, True),
    #(domain.InvalidRoomId, 5, False, False, True),
    #(domain.RoomNotFound, 5, False, False, True),
    #(domain.RoomMismatch, 3, False, False, True),
    #(domain.InvalidEvent, 5, False, False, True),
    #(domain.RoomFull, 5, False, False, True),
    #(domain.RoomUnavailable, 3, False, False, True),
  ]

  list.each(cases, fn(item) {
    let #(
      code,
      expected_phase,
      expected_in_flight,
      field_error,
      connection_error,
    ) = item
    let state =
      model.Model(
        ..joined_model(25, self_id, []),
        draft: "preserve me",
        send_in_flight: Some(model.SendInFlight(25, "preserve me")),
      )
    let #(updated, _) =
      update.transition(
        state,
        update.ServerEvent(25, 4000, domain.ServerError(error_event(code))),
      )

    assert phase_kind(updated.phase) == expected_phase
    assert updated.draft == "preserve me"
    assert option_present(updated.send_in_flight) == expected_in_flight
    assert option_present(updated.feedback) == field_error
    assert option_present(updated.connection_feedback) == connection_error
  })
}

pub fn inactive_phases_ignore_every_server_error_test() {
  let inactive_phases = [
    model.ChoosingUsername,
    model.WaitingToReconnect(2, 1, 500),
    model.Blocked(model.ProtocolFailure),
  ]
  let codes = [
    domain.InvalidEvent,
    domain.JoinRequired,
    domain.AlreadyJoined,
    domain.InvalidRoomId,
    domain.RoomNotFound,
    domain.RoomMismatch,
    domain.RoomUnavailable,
    domain.InvalidUsername,
    domain.InvalidMessage,
    domain.RateLimited,
    domain.RoomFull,
  ]

  list.each(inactive_phases, fn(phase) {
    list.each(codes, fn(code) {
      let state = model_for_phase(phase)
      let #(updated, commands) =
        update.transition(
          state,
          update.ServerEvent(1, 4000, domain.ServerError(error_event(code))),
        )
      assert updated == state
      assert commands == []
    })
  })
}

pub fn active_wrong_generation_errors_are_ignored_test() {
  let phases = [
    model.Connecting(10, 0),
    model.AwaitingRoomState(10, 0),
    model.Joined(10, domain.connection_id_from_string("self")),
  ]
  let codes = [
    domain.InvalidEvent,
    domain.JoinRequired,
    domain.AlreadyJoined,
    domain.InvalidRoomId,
    domain.RoomNotFound,
    domain.RoomMismatch,
    domain.RoomUnavailable,
    domain.InvalidUsername,
    domain.InvalidMessage,
    domain.RateLimited,
    domain.RoomFull,
  ]

  list.each(phases, fn(phase) {
    list.each(codes, fn(code) {
      let state = model_for_phase(phase)
      let #(updated, commands) =
        update.transition(
          state,
          update.ServerEvent(9, 4000, domain.ServerError(error_event(code))),
        )
      assert updated == state
      assert commands == []
    })
  })
}

pub fn malformed_server_data_fails_closed_only_for_active_generation_test() {
  let self_id = domain.connection_id_from_string("self")
  let active =
    model.Model(
      ..joined_model(26, self_id, []),
      draft: "preserve me",
      send_in_flight: Some(model.SendInFlight(26, "preserve me")),
      rate_limit_until: Some(5000),
    )

  let #(blocked, commands) =
    update.transition(active, update.ServerDecodeFailed(26))
  assert blocked.phase == model.Blocked(model.ProtocolFailure)
  assert snapshot_is_stale(blocked)
  assert blocked.draft == "preserve me"
  assert blocked.send_in_flight == None
  assert blocked.rate_limit_until == None
  assert blocked.connection_feedback == Some("Protocol error.")
  assert commands == [update.CloseSocket(26), update.CancelRateLimit(26, 5000)]

  let #(stale, stale_commands) =
    update.transition(active, update.ServerDecodeFailed(25))
  assert stale == active
  assert stale_commands == []

  let inactive_phases = [
    model.ChoosingUsername,
    model.WaitingToReconnect(27, 1, 500),
    model.Blocked(model.ProtocolFailure),
  ]
  list.each(inactive_phases, fn(phase) {
    let inactive = model_for_phase(phase)
    let #(ignored, ignored_commands) =
      update.transition(inactive, update.ServerDecodeFailed(26))
    assert ignored == inactive
    assert ignored_commands == []
  })

  let #(unknown, unknown_commands) =
    update.transition(active, update.ServerEvent(26, 4000, domain.UnknownEvent))
  assert unknown == active
  assert unknown_commands == []
}

pub fn current_generation_wrong_room_structured_error_fails_closed_test() {
  let self_id = domain.connection_id_from_string("self")
  let other_room = domain.room_id_from_string("other")
  let active =
    model.Model(
      ..joined_model(27, self_id, []),
      draft: "preserve me",
      send_in_flight: Some(model.SendInFlight(27, "preserve me")),
      rate_limit_until: Some(5000),
    )
  let event =
    domain.ServerError(domain.ErrorEvent(
      Some(other_room),
      domain.InvalidMessage,
      "server feedback",
      True,
    ))

  let #(blocked, commands) =
    update.transition(active, update.ServerEvent(27, 4000, event))
  assert blocked.phase == model.Blocked(model.ProtocolFailure)
  assert snapshot_is_stale(blocked)
  assert blocked.draft == "preserve me"
  assert blocked.send_in_flight == None
  assert blocked.rate_limit_until == None
  assert blocked.connection_feedback == Some("Protocol error.")
  assert commands == [update.CloseSocket(27), update.CancelRateLimit(27, 5000)]

  let #(stale, stale_commands) =
    update.transition(active, update.ServerEvent(26, 4000, event))
  assert stale == active
  assert stale_commands == []
}

fn option_present(value: Option(a)) -> Bool {
  case value {
    Some(_) -> True
    None -> False
  }
}

fn joined_model(
  generation: Int,
  self_id: domain.ConnectionId,
  participants: List(domain.Presence),
) -> model.Model {
  let initial = model.initial()
  model.Model(
    ..initial,
    phase: model.Joined(generation, self_id),
    socket_generation: generation,
    room_snapshot: Some(model.RoomSnapshot(
      domain.default_room_id,
      self_id,
      participants,
      [],
      False,
    )),
  )
}

fn model_for_phase(phase: model.ConnectionPhase) -> model.Model {
  let initial = model.initial()
  case phase {
    model.Joined(generation, self_id) ->
      model.Model(
        ..joined_model(generation, self_id, []),
        username_preference: "Ada",
        username_input: "Ada",
      )
    _ ->
      model.Model(
        ..initial,
        username_preference: "Ada",
        username_input: "Ada",
        phase: phase,
        socket_generation: 1,
      )
  }
}

fn error_event(code: domain.ErrorCode) -> domain.ErrorEvent {
  error_event_with_recoverability(code, expected_recoverability(code))
}

fn error_event_with_recoverability(
  code: domain.ErrorCode,
  recoverable: Bool,
) -> domain.ErrorEvent {
  let room_id = case code {
    domain.InvalidEvent | domain.InvalidRoomId -> None
    domain.RoomMismatch -> Some(domain.room_id_from_string("other"))
    _ -> Some(domain.default_room_id)
  }
  domain.ErrorEvent(room_id, code, "server feedback", recoverable)
}

fn expected_recoverability(code: domain.ErrorCode) -> Bool {
  case code {
    domain.InvalidEvent -> False
    domain.RoomUnavailable -> False
    domain.RoomFull -> False
    _ -> True
  }
}

fn snapshot_messages(state: model.Model) -> List(domain.ChatMessage) {
  case state.room_snapshot {
    Some(snapshot) -> snapshot.messages
    None -> []
  }
}

fn snapshot_is_stale(state: model.Model) -> Bool {
  case state.room_snapshot {
    Some(snapshot) -> snapshot.stale
    None -> False
  }
}

fn message(
  message_id: String,
  sender_id: domain.ConnectionId,
  text: String,
) -> domain.ChatMessage {
  domain.ChatMessage(
    domain.message_id_from_string(message_id),
    sender_id,
    "Ada",
    text,
    "2026-08-10T12:00:00Z",
  )
}

fn numbered_messages(
  current: Int,
  last: Int,
  sender_id: domain.ConnectionId,
) -> List(domain.ChatMessage) {
  case current > last {
    True -> []
    False -> [
      message(
        "message-" <> int.to_string(current),
        sender_id,
        "message " <> int.to_string(current),
      ),
      ..numbered_messages(current + 1, last, sender_id)
    ]
  }
}

fn snapshot_participants(state: model.Model) -> List(domain.Presence) {
  case state.room_snapshot {
    Some(snapshot) -> snapshot.participants
    None -> []
  }
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
