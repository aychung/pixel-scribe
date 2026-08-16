import gleam/list
import gleam/option.{type Option, None, Some}
import pixel_scribe_frontend/camera
import pixel_scribe_frontend/canvas
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/model.{type Model}
import pixel_scribe_frontend/placement
import pixel_scribe_frontend/protocol
import pixel_scribe_frontend/reconnect
import pixel_scribe_frontend/scene as office_scene
import pixel_scribe_frontend/validation

/// Trusted application inputs and decoded server events. Raw browser payloads
/// are intentionally absent: protocol decoding happens before ServerEvent.
pub type Msg {
  UsernameInput(value: String)
  SubmitUsername
  DraftInput(value: String)
  SubmitMessage
  SocketOpened(generation: Int)
  SocketClosed(generation: Int, deliberate: Bool, random_unit: Float)
  SocketError(generation: Int, random_unit: Float)
  ServerEvent(generation: Int, received_at_ms: Int, event: domain.ServerEvent)
  AcceptedMessage(
    generation: Int,
    room_id: domain.RoomId,
    message: domain.ChatMessage,
    reader_was_near_bottom: Bool,
  )
  ServerDecodeFailed(generation: Int)
  CanvasReady(width: Int, height: Int, dpr: Float)
  CanvasResized(width: Int, height: Int, dpr: Float)
  CanvasFailed(reason: canvas.Error)
  ReconnectTimerFired(generation: Int, timer_id: Int)
  RateLimitTimerFired(generation: Int, deadline_ms: Int)
  RetryRequested
  ReturnToUsername
}

/// External work is data, not a browser handle. A later effect interpreter will
/// turn these commands into Lustre effects without moving side effects into the
/// pure transition function.
pub type Command {
  OpenSocket(generation: Int)
  CloseSocket(generation: Int)
  SendSocketFrame(generation: Int, frame: String)
  WriteUsernamePreference(username: String)
  ScheduleReconnect(generation: Int, timer_id: Int, delay_ms: Int)
  CancelReconnect(generation: Int, timer_id: Int)
  ScheduleRateLimit(generation: Int, deadline_ms: Int, delay_ms: Int)
  CancelRateLimit(generation: Int, deadline_ms: Int)
  FocusUsername
  FocusComposer
  ScrollChatToEnd
}

/// The pure transition seam used by state-machine work. Browser effects are
/// represented by commands and interpreted by the Lustre wrapper later.
pub fn transition(model: Model, message: Msg) -> #(Model, List(Command)) {
  case message {
    UsernameInput(value) -> #(
      model.Model(..model, username_input: value, feedback: None),
      [],
    )
    DraftInput(value) -> #(
      model.Model(..model, draft: value, feedback: None),
      [],
    )
    SubmitUsername -> submit_username(model)
    SubmitMessage -> submit_message(model)
    SocketOpened(generation) -> socket_opened(model, generation)
    SocketClosed(generation, deliberate, random_unit) ->
      socket_closed(model, generation, deliberate, random_unit)
    SocketError(generation, random_unit) ->
      socket_error(model, generation, random_unit)
    ServerEvent(generation, received_at_ms, event) ->
      server_event(model, generation, received_at_ms, event)
    AcceptedMessage(generation, room_id, accepted, reader_was_near_bottom) ->
      route_accepted_message(
        model,
        generation,
        room_id,
        accepted,
        reader_was_near_bottom,
      )
    ServerDecodeFailed(generation) -> server_decode_failed(model, generation)
    CanvasReady(width, height, _) -> {
      let camera_ready = update_camera(model, width, height)
      let recovered = clear_renderer_feedback(camera_ready)
      #(recovered, [])
    }
    CanvasResized(width, height, _) -> {
      let resized = update_camera(model, width, height)
      #(resized, [])
    }
    CanvasFailed(reason) -> #(
      record_renderer_feedback(model, canvas_status(reason)),
      [],
    )
    RateLimitTimerFired(generation, deadline_ms) ->
      rate_limit_timer_fired(model, generation, deadline_ms)
    ReconnectTimerFired(generation, timer_id) ->
      reconnect_timer_fired(model, generation, timer_id)
    RetryRequested -> retry_requested(model)
    ReturnToUsername -> return_to_username(model)
  }
}

fn route_accepted_message(
  model: Model,
  generation: Int,
  room_id: domain.RoomId,
  message: domain.ChatMessage,
  reader_was_near_bottom: Bool,
) -> #(Model, List(Command)) {
  case current_phase_generation(model.phase) {
    Some(expected_generation) if expected_generation != generation -> #(
      model,
      [],
    )
    Some(expected_generation)
      if expected_generation == generation && room_id != domain.default_room_id
    -> protocol_failure(model, generation)
    _ ->
      accepted_message(
        model,
        generation,
        room_id,
        message,
        reader_was_near_bottom,
      )
  }
}

/// Applies the one-time browser startup values without making them part of the
/// public user-action message set. The browser boundary already validates the
/// cookie, but validating again keeps this application-owned seam defensive.
pub fn apply_browser_startup(
  model: Model,
  preference: Option(String),
  seed: Int,
) -> Model {
  let validated_preference = case preference {
    Some(value) ->
      case validation.normalize_username(value) {
        Ok(username) -> Some(username)
        Error(_) -> None
      }
    None -> None
  }
  let username_preference = case validated_preference {
    Some(value) -> value
    None -> ""
  }
  let username_input = case model.username_input, validated_preference {
    "", Some(value) -> value
    _, _ -> model.username_input
  }
  model.Model(
    ..model,
    username_preference: username_preference,
    username_input: username_input,
    placement_seed: Some(seed),
  )
}

fn submit_username(model: Model) -> #(Model, List(Command)) {
  case model.phase {
    model.ChoosingUsername -> submit_choosing_username(model)
    _ -> #(model, [])
  }
}

fn submit_choosing_username(model: Model) -> #(Model, List(Command)) {
  case validation.normalize_username(model.username_input) {
    Error(reason) -> #(
      model.Model(..model, feedback: Some(username_feedback(reason))),
      [],
    )
    Ok(username) ->
      case protocol.encode_join_room(username) {
        Error(protocol.FrameTooLarge) -> #(
          model.Model(
            ..model,
            username_input: username,
            feedback: Some("Username is too large to send."),
          ),
          [],
        )
        Ok(_) -> {
          let generation = model.socket_generation + 1
          let updated =
            model.Model(
              ..model,
              username_preference: username,
              username_input: username,
              phase: model.Connecting(generation, model.reconnect_attempt),
              socket_generation: generation,
              feedback: None,
              connection_feedback: None,
            )
          #(updated, [
            WriteUsernamePreference(username),
            OpenSocket(generation),
          ])
        }
      }
  }
}

fn username_feedback(reason: validation.UsernameError) -> String {
  case reason {
    validation.UsernameEmpty -> "Enter a username."
    validation.UsernameTooLong -> "Username must be 32 characters or fewer."
    validation.UsernameContainsControlCharacter ->
      "Username cannot contain control characters or line breaks."
  }
}

fn submit_message(model: Model) -> #(Model, List(Command)) {
  case model.phase, model.send_in_flight, model.room_snapshot {
    model.Joined(generation, self_id), None, Some(snapshot)
      if snapshot.room_id == domain.default_room_id
      && snapshot.self_id == self_id
      && !snapshot.stale
      && model.rate_limit_until == None
    -> submit_validated_message(model, generation)
    _, _, _ -> #(model, [])
  }
}

fn submit_validated_message(
  model: Model,
  generation: Int,
) -> #(Model, List(Command)) {
  case validation.normalize_message_text(model.draft) {
    Error(reason) -> #(
      model.Model(..model, feedback: Some(message_feedback(reason))),
      [],
    )
    Ok(text) ->
      case protocol.encode_send_message(text) {
        Error(protocol.FrameTooLarge) -> #(
          model.Model(..model, feedback: Some("Message is too large to send.")),
          [],
        )
        Ok(frame) -> #(
          model.Model(
            ..model,
            draft: text,
            send_in_flight: Some(model.SendInFlight(generation, text)),
            feedback: None,
          ),
          [SendSocketFrame(generation, frame)],
        )
      }
  }
}

fn message_feedback(reason: validation.MessageTextError) -> String {
  case reason {
    validation.MessageTextEmpty -> "Enter a message."
    validation.MessageTextTooLong -> "Message must be 500 characters or fewer."
    validation.MessageTextContainsControlCharacter ->
      "Message contains an unsupported control character."
  }
}

fn socket_opened(model: Model, generation: Int) -> #(Model, List(Command)) {
  case model.phase {
    model.Connecting(expected_generation, attempt)
      if expected_generation == generation
    ->
      case protocol.encode_join_room(model.username_preference) {
        Ok(frame) -> #(
          model.Model(
            ..model,
            phase: model.AwaitingRoomState(generation, attempt),
          ),
          [SendSocketFrame(generation, frame)],
        )
        Error(protocol.FrameTooLarge) -> #(
          model.Model(..model, feedback: Some("Username is too large to send.")),
          [],
        )
      }
    _ -> #(model, [])
  }
}

fn server_event(
  model: Model,
  generation: Int,
  received_at_ms: Int,
  event: domain.ServerEvent,
) -> #(Model, List(Command)) {
  case current_phase_generation(model.phase) {
    Some(expected_generation) if expected_generation != generation -> #(
      model,
      [],
    )
    _ ->
      case event {
        domain.ServerError(error) ->
          server_error(model, generation, received_at_ms, error)
        _ ->
          case room_id_for_event(event), current_phase_generation(model.phase) {
            Some(room_id), Some(expected_generation)
              if expected_generation == generation
              && room_id != domain.default_room_id
            -> protocol_failure(model, generation)
            _, _ -> dispatch_server_event(model, generation, event)
          }
      }
  }
}

fn server_decode_failed(
  model: Model,
  generation: Int,
) -> #(Model, List(Command)) {
  case is_current_generation(model.phase, generation) {
    True -> protocol_failure(model, generation)
    False -> #(model, [])
  }
}

fn room_id_for_event(event: domain.ServerEvent) -> Option(domain.RoomId) {
  case event {
    domain.RoomState(room_id, _, _, _)
    | domain.UserJoined(room_id, _)
    | domain.UserLeft(room_id, _)
    | domain.MessageSent(room_id, _) -> Some(room_id)
    _ -> None
  }
}

fn dispatch_server_event(
  model: Model,
  generation: Int,
  event: domain.ServerEvent,
) -> #(Model, List(Command)) {
  case event {
    domain.RoomState(room_id, self_id, users, messages) ->
      case model.phase {
        model.AwaitingRoomState(expected_generation, _)
          if expected_generation == generation
          && room_id == domain.default_room_id
        ->
          case snapshot_participants_are_valid(users, self_id) {
            True -> {
              let snapshot =
                model.RoomSnapshot(
                  room_id,
                  self_id,
                  users,
                  latest_unique_messages(messages),
                  False,
                )
              let updated_model =
                model.Model(
                  ..model,
                  phase: model.Joined(generation, self_id),
                  room_snapshot: Some(snapshot),
                  reconnect_attempt: 0,
                  reconnect_timer: None,
                  connection_feedback: None,
                )
              #(
                reconcile_scene(updated_model, snapshot),
                cancel_reconnect(model),
              )
            }
            False -> protocol_failure(model, generation)
          }
        _ -> #(model, [])
      }
    domain.UserJoined(room_id, user) ->
      case model.phase, model.room_snapshot {
        model.Joined(expected_generation, _), Some(snapshot)
          if expected_generation == generation
          && room_id == snapshot.room_id
          && !snapshot.stale
        -> {
          let updated_snapshot =
            model.RoomSnapshot(
              ..snapshot,
              participants: upsert_presence(snapshot.participants, user),
            )
          let updated_model =
            reconcile_scene(
              model.Model(..model, room_snapshot: Some(updated_snapshot)),
              updated_snapshot,
            )
          #(updated_model, [])
        }
        _, _ -> #(model, [])
      }
    domain.UserLeft(room_id, connection_id) ->
      case model.phase, model.room_snapshot {
        model.Joined(expected_generation, self_id), Some(snapshot)
          if expected_generation == generation
          && room_id == snapshot.room_id
          && !snapshot.stale
          && connection_id == self_id
        -> protocol_failure(model, generation)
        model.Joined(expected_generation, _), Some(snapshot)
          if expected_generation == generation
          && room_id == snapshot.room_id
          && !snapshot.stale
        -> {
          let updated_snapshot =
            model.RoomSnapshot(
              ..snapshot,
              participants: remove_presence(
                snapshot.participants,
                connection_id,
              ),
            )
          let updated_model =
            reconcile_scene(
              model.Model(..model, room_snapshot: Some(updated_snapshot)),
              updated_snapshot,
            )
          case updated_snapshot.participants == snapshot.participants {
            True -> #(model, [])
            False -> #(updated_model, [])
          }
        }
        _, _ -> #(model, [])
      }
    domain.MessageSent(room_id, message) ->
      accepted_message(model, generation, room_id, message, False)
    domain.UnknownEvent -> #(model, [])
    // ServerError is handled by server_event before reaching this dispatcher.
    // Naming it here keeps new ServerEvent variants compiler-checked.
    domain.ServerError(_) -> #(model, [])
  }
}

fn server_error(
  model: Model,
  generation: Int,
  received_at_ms: Int,
  error: domain.ErrorEvent,
) -> #(Model, List(Command)) {
  case current_phase_generation(model.phase) {
    Some(expected_generation) if expected_generation == generation ->
      case
        server_error_context_matches(model.phase, error),
        recoverability_matches(error)
      {
        True, True ->
          apply_server_error(model, generation, received_at_ms, error)
        _, _ -> protocol_failure(model, generation)
      }
    _ -> #(model, [])
  }
}

fn server_error_context_matches(
  phase: model.ConnectionPhase,
  error: domain.ErrorEvent,
) -> Bool {
  case error.code {
    domain.InvalidEvent | domain.InvalidRoomId -> error.room_id == None
    domain.RoomMismatch ->
      case phase, error.room_id {
        model.Joined(_, _), Some(room_id) -> room_id != domain.default_room_id
        _, _ -> False
      }
    domain.JoinRequired -> is_awaiting_phase(phase) && has_default_room(error)
    domain.AlreadyJoined ->
      is_awaiting_or_joined_phase(phase) && has_default_room(error)
    domain.RoomNotFound -> is_awaiting_phase(phase) && has_default_room(error)
    domain.RoomUnavailable ->
      is_awaiting_or_joined_phase(phase) && has_default_room(error)
    domain.RoomFull -> is_awaiting_phase(phase) && has_default_room(error)
    domain.RateLimited -> is_joined_phase(phase) && has_default_room(error)
    domain.InvalidUsername | domain.InvalidMessage ->
      is_active_phase(phase) && has_default_room(error)
  }
}

fn has_default_room(error: domain.ErrorEvent) -> Bool {
  error.room_id == Some(domain.default_room_id)
}

fn is_active_phase(phase: model.ConnectionPhase) -> Bool {
  case phase {
    model.Connecting(_, _)
    | model.AwaitingRoomState(_, _)
    | model.Joined(_, _) -> True
    _ -> False
  }
}

fn is_awaiting_phase(phase: model.ConnectionPhase) -> Bool {
  case phase {
    model.AwaitingRoomState(_, _) -> True
    _ -> False
  }
}

fn is_joined_phase(phase: model.ConnectionPhase) -> Bool {
  case phase {
    model.Joined(_, _) -> True
    _ -> False
  }
}

fn is_awaiting_or_joined_phase(phase: model.ConnectionPhase) -> Bool {
  is_awaiting_phase(phase) || is_joined_phase(phase)
}

fn apply_server_error(
  model: Model,
  generation: Int,
  received_at_ms: Int,
  error: domain.ErrorEvent,
) -> #(Model, List(Command)) {
  case error.code {
    domain.InvalidUsername -> invalid_username_error(model, generation, error)
    domain.InvalidMessage -> invalid_message_error(model, error)
    domain.RateLimited ->
      rate_limited_error(model, generation, received_at_ms, error)
    domain.JoinRequired -> join_required_error(model, generation, error)
    domain.AlreadyJoined -> connection_feedback(model, error)
    domain.InvalidRoomId ->
      terminal_blocked_error(model, generation, model.OfficeUnavailable, error)
    domain.RoomNotFound ->
      terminal_blocked_error(model, generation, model.OfficeUnavailable, error)
    domain.RoomMismatch -> room_mismatch_error(model, error)
    domain.InvalidEvent -> protocol_failure(model, generation)
    domain.RoomFull ->
      terminal_blocked_error(model, generation, model.RoomFull, error)
    domain.RoomUnavailable -> room_unavailable_error(model, generation, error)
  }
}

fn recoverability_matches(error: domain.ErrorEvent) -> Bool {
  let expected = case error.code {
    domain.InvalidEvent -> False
    domain.RoomUnavailable -> False
    domain.RoomFull -> False
    _ -> True
  }
  error.recoverable == expected
}

fn current_phase_generation(phase: model.ConnectionPhase) -> Option(Int) {
  case phase {
    model.Connecting(generation, _) -> Some(generation)
    model.AwaitingRoomState(generation, _) -> Some(generation)
    model.Joined(generation, _) -> Some(generation)
    _ -> None
  }
}

fn protocol_failure(model: Model, generation: Int) -> #(Model, List(Command)) {
  let updated =
    model.Model(
      ..model,
      phase: model.Blocked(model.ProtocolFailure),
      room_snapshot: mark_snapshot_stale(model.room_snapshot),
      send_in_flight: None,
      rate_limit_until: None,
      feedback: None,
      connection_feedback: Some("Protocol error."),
    )
  #(updated, [CloseSocket(generation), ..cancel_rate_limit(model, generation)])
}

fn invalid_username_error(
  model: Model,
  generation: Int,
  error: domain.ErrorEvent,
) -> #(Model, List(Command)) {
  let updated =
    model.Model(
      ..model,
      phase: model.ChoosingUsername,
      room_snapshot: None,
      send_in_flight: None,
      rate_limit_until: None,
      feedback: Some(error.message),
      connection_feedback: None,
    )
  let commands =
    [CloseSocket(generation)]
    |> list.append(cancel_rate_limit(model, generation))
    |> list.append([FocusUsername])
  #(updated, commands)
}

fn invalid_message_error(
  model: Model,
  error: domain.ErrorEvent,
) -> #(Model, List(Command)) {
  #(
    model.Model(
      ..model,
      send_in_flight: None,
      feedback: Some(error.message),
      connection_feedback: None,
    ),
    [FocusComposer],
  )
}

fn rate_limited_error(
  model: Model,
  generation: Int,
  received_at_ms: Int,
  error: domain.ErrorEvent,
) -> #(Model, List(Command)) {
  let deadline_ms = received_at_ms + 1000
  let timer_commands = case model.rate_limit_until {
    None -> [ScheduleRateLimit(generation, deadline_ms, 1000)]
    Some(previous_deadline) if previous_deadline == deadline_ms -> []
    Some(previous_deadline) -> [
      CancelRateLimit(generation, previous_deadline),
      ScheduleRateLimit(generation, deadline_ms, 1000),
    ]
  }
  #(
    model.Model(
      ..model,
      send_in_flight: None,
      feedback: Some(error.message),
      connection_feedback: None,
      rate_limit_until: Some(deadline_ms),
    ),
    timer_commands,
  )
}

fn join_required_error(
  model: Model,
  generation: Int,
  error: domain.ErrorEvent,
) -> #(Model, List(Command)) {
  let snapshot = case model.phase {
    model.Joined(_, _) -> mark_snapshot_stale(model.room_snapshot)
    _ -> model.room_snapshot
  }
  let updated =
    model.Model(
      ..model,
      room_snapshot: snapshot,
      send_in_flight: None,
      rate_limit_until: None,
      feedback: None,
      connection_feedback: Some(error.message),
    )
  #(updated, cancel_rate_limit(model, generation))
}

fn connection_feedback(
  model: Model,
  error: domain.ErrorEvent,
) -> #(Model, List(Command)) {
  #(
    model.Model(
      ..model,
      feedback: None,
      connection_feedback: Some(error.message),
    ),
    [],
  )
}

fn room_mismatch_error(
  model: Model,
  error: domain.ErrorEvent,
) -> #(Model, List(Command)) {
  #(
    model.Model(
      ..model,
      send_in_flight: None,
      feedback: None,
      connection_feedback: Some(error.message),
    ),
    [],
  )
}

fn terminal_blocked_error(
  model: Model,
  generation: Int,
  reason: model.BlockReason,
  error: domain.ErrorEvent,
) -> #(Model, List(Command)) {
  let updated =
    model.Model(
      ..model,
      phase: model.Blocked(reason),
      room_snapshot: mark_snapshot_stale(model.room_snapshot),
      send_in_flight: None,
      rate_limit_until: None,
      feedback: None,
      connection_feedback: Some(error.message),
    )
  #(updated, [CloseSocket(generation), ..cancel_rate_limit(model, generation)])
}

fn room_unavailable_error(
  model: Model,
  generation: Int,
  error: domain.ErrorEvent,
) -> #(Model, List(Command)) {
  let updated =
    model.Model(
      ..model,
      room_snapshot: mark_snapshot_stale(model.room_snapshot),
      send_in_flight: None,
      rate_limit_until: None,
      feedback: None,
      connection_feedback: Some(error.message),
    )
  #(updated, cancel_rate_limit(model, generation))
}

fn cancel_rate_limit(model: Model, generation: Int) -> List(Command) {
  case model.rate_limit_until {
    Some(deadline_ms) -> [CancelRateLimit(generation, deadline_ms)]
    None -> []
  }
}

fn rate_limit_timer_fired(
  model: Model,
  generation: Int,
  deadline_ms: Int,
) -> #(Model, List(Command)) {
  case current_phase_generation(model.phase), model.rate_limit_until {
    Some(expected_generation), Some(expected_deadline)
      if expected_generation == generation && expected_deadline == deadline_ms
    -> #(model.Model(..model, rate_limit_until: None), [])
    _, _ -> #(model, [])
  }
}

fn accepted_message(
  model: Model,
  generation: Int,
  room_id: domain.RoomId,
  message: domain.ChatMessage,
  reader_was_near_bottom: Bool,
) -> #(Model, List(Command)) {
  case model.phase, model.room_snapshot {
    model.Joined(expected_generation, self_id), Some(snapshot)
      if expected_generation == generation
      && room_id == domain.default_room_id
      && room_id == snapshot.room_id
      && !snapshot.stale
    ->
      case has_message_id(snapshot.messages, message.message_id) {
        True -> #(model, [])
        False -> {
          let messages = append_message(snapshot.messages, message)
          let #(draft, send_in_flight) =
            accepted_send_state(model, generation, self_id, message)
          let updated_snapshot =
            model.RoomSnapshot(..snapshot, messages: messages)
          let scroll = case
            message.sender_id == self_id || reader_was_near_bottom
          {
            True -> [ScrollChatToEnd]
            False -> []
          }
          #(
            model.Model(
              ..model,
              room_snapshot: Some(updated_snapshot),
              draft: draft,
              send_in_flight: send_in_flight,
            ),
            scroll,
          )
        }
      }
    _, _ -> #(model, [])
  }
}

fn accepted_send_state(
  model: Model,
  generation: Int,
  self_id: domain.ConnectionId,
  message: domain.ChatMessage,
) -> #(String, Option(model.SendInFlight)) {
  case model.send_in_flight {
    Some(in_flight)
      if in_flight.generation == generation
      && message.sender_id == self_id
      && message.text == in_flight.text
    -> {
      let draft = case model.draft == in_flight.text {
        True -> ""
        False -> model.draft
      }
      #(draft, None)
    }
    _ -> #(model.draft, model.send_in_flight)
  }
}

fn append_message(
  messages: List(domain.ChatMessage),
  message: domain.ChatMessage,
) -> List(domain.ChatMessage) {
  messages
  |> list.append([message])
  |> latest_50
}

fn reconcile_scene(model: Model, snapshot: model.RoomSnapshot) -> Model {
  let seed = case model.placement_seed {
    Some(value) -> value
    None -> 0
  }
  let previous = case model.scene {
    model.Placeholder -> []
    model.Ready(_, _, placements, _, _, _) -> placements
    model.Failed(_) -> []
  }
  let renderer_feedback = case model.scene {
    model.Ready(_, _, _, _, _, feedback) -> feedback
    model.Failed(reason) -> Some(reason)
    model.Placeholder -> None
  }

  case placement.reconcile(seed, previous, snapshot.participants) {
    Ok(placements) -> {
      let inputs =
        list.filter_map(snapshot.participants, fn(presence) {
          let domain.Presence(connection_id, username) = presence
          case placement.anchor_for(connection_id, placements) {
            Ok(anchor) -> {
              let office_scene.Anchor(_, position) = anchor
              Ok(office_scene.AvatarInput(
                connection_id: connection_id,
                username: username,
                bottom_anchor: position,
                status: office_scene.Online,
              ))
            }
            Error(_) -> Error(Nil)
          }
        })
      let render_data = office_scene.render_data(seed, snapshot.self_id, inputs)
      let camera_state =
        reconcile_camera(model.scene, snapshot.self_id, placements)
      model.Model(
        ..model,
        scene: model.Ready(
          seed,
          snapshot.self_id,
          placements,
          render_data,
          camera_state,
          renderer_feedback,
        ),
      )
    }
    Error(_) -> model.Model(..model, scene: model.Placeholder)
  }
}

fn record_renderer_feedback(model: Model, message: String) -> Model {
  case model.scene {
    model.Ready(seed, self_id, placements, data, camera_state, _) ->
      model.Model(
        ..model,
        scene: model.Ready(
          seed,
          self_id,
          placements,
          data,
          camera_state,
          Some(message),
        ),
      )
    model.Failed(_) | model.Placeholder ->
      model.Model(..model, scene: model.Failed(message))
  }
}

fn clear_renderer_feedback(model: Model) -> Model {
  case model.scene {
    model.Ready(seed, self_id, placements, data, camera_state, Some(_)) ->
      model.Model(
        ..model,
        scene: model.Ready(seed, self_id, placements, data, camera_state, None),
      )
    _ -> model
  }
}

fn reconcile_camera(
  state: model.SceneState,
  self_id: domain.ConnectionId,
  placements: List(placement.Placement),
) -> Option(camera.Camera) {
  case state {
    model.Ready(_, _, _, _, Some(existing), _) -> {
      let camera.Camera(_, _, previous_self_id) = existing
      let result = case previous_self_id == self_id {
        True -> camera.update(existing, placements)
        False -> camera.retarget(existing, self_id, placements)
      }
      case result {
        Ok(value) -> Some(value)
        Error(_) -> None
      }
    }
    _ -> None
  }
}

fn update_camera(model: Model, width: Int, height: Int) -> Model {
  case model.scene {
    model.Ready(seed, self_id, placements, data, current, feedback) -> {
      let next = case current {
        Some(existing) -> camera.resize(existing, width, height, placements)
        None -> camera.new(width, height, self_id, placements)
      }
      case next {
        Ok(camera_state) ->
          model.Model(
            ..model,
            scene: model.Ready(
              seed,
              self_id,
              placements,
              data,
              Some(camera_state),
              feedback,
            ),
          )
        Error(_) -> model
      }
    }
    _ -> model
  }
}

fn canvas_status(reason: canvas.Error) -> String {
  case reason {
    canvas.AssetUnavailable ->
      "Office art unavailable; showing fallback geometry."
    canvas.SceneUnavailable ->
      "Office scene unavailable; showing fallback geometry."
    canvas.CanvasUnavailable -> "Office canvas unavailable."
    canvas.ContextUnavailable -> "Office drawing is unavailable."
    canvas.ResizeObserverUnavailable -> "Office resizing is unavailable."
    canvas.GeometryUnavailable -> "Office layout could not be measured."
    canvas.InitializationFailed -> "Office drawing could not start."
    canvas.Unknown -> "Office drawing reported an unknown problem."
  }
}

fn latest_unique_messages(
  messages: List(domain.ChatMessage),
) -> List(domain.ChatMessage) {
  messages
  |> unique_messages([])
  |> latest_50
}

fn unique_messages(
  messages: List(domain.ChatMessage),
  seen: List(domain.MessageId),
) -> List(domain.ChatMessage) {
  case messages {
    [] -> []
    [message, ..rest] ->
      case list.contains(seen, message.message_id) {
        True -> unique_messages(rest, seen)
        False -> [
          message,
          ..unique_messages(rest, [message.message_id, ..seen])
        ]
      }
  }
}

fn has_message_id(
  messages: List(domain.ChatMessage),
  message_id: domain.MessageId,
) -> Bool {
  case messages {
    [] -> False
    [message, ..rest] ->
      case message.message_id == message_id {
        True -> True
        False -> has_message_id(rest, message_id)
      }
  }
}

fn latest_50(messages: List(domain.ChatMessage)) -> List(domain.ChatMessage) {
  let overflow = list.length(messages) - 50

  case overflow > 0 {
    True -> list.drop(messages, overflow)
    False -> messages
  }
}

fn socket_closed(
  model: Model,
  generation: Int,
  deliberate: Bool,
  random_unit: Float,
) -> #(Model, List(Command)) {
  case is_current_generation(model.phase, generation) {
    False -> #(model, [])
    True ->
      case deliberate {
        True -> cleanup_closed_socket(model, generation)
        False -> schedule_reconnect(model, generation, random_unit)
      }
  }
}

fn socket_error(
  model: Model,
  generation: Int,
  random_unit: Float,
) -> #(Model, List(Command)) {
  case is_current_generation(model.phase, generation) {
    False -> #(model, [])
    True -> schedule_reconnect(model, generation, random_unit)
  }
}

fn cleanup_closed_socket(
  model: Model,
  generation: Int,
) -> #(Model, List(Command)) {
  let updated =
    model.Model(
      ..model,
      room_snapshot: mark_snapshot_stale(model.room_snapshot),
      send_in_flight: None,
      rate_limit_until: None,
    )
  #(updated, cancel_rate_limit(model, generation))
}

fn schedule_reconnect(
  model: Model,
  generation: Int,
  random_unit: Float,
) -> #(Model, List(Command)) {
  let next_generation = model.socket_generation + 1
  let next_attempt = model.reconnect_attempt + 1
  let delay_ms = reconnect.delay_ms(model.reconnect_attempt, random_unit)
  let timer_id = next_generation
  let updated =
    model.Model(
      ..model,
      phase: model.WaitingToReconnect(next_generation, next_attempt, delay_ms),
      socket_generation: next_generation,
      reconnect_attempt: next_attempt,
      reconnect_timer: Some(model.ReconnectTimer(next_generation, timer_id)),
      room_snapshot: mark_snapshot_stale(model.room_snapshot),
      send_in_flight: None,
      rate_limit_until: None,
    )
  let commands = cancel_rate_limit(model, generation)
  #(
    updated,
    list.append(commands, [
      ScheduleReconnect(next_generation, timer_id, delay_ms),
    ]),
  )
}

fn reconnect_timer_fired(
  model: Model,
  generation: Int,
  timer_id: Int,
) -> #(Model, List(Command)) {
  case model.phase, model.reconnect_timer {
    model.WaitingToReconnect(next_generation, attempt, _),
      Some(model.ReconnectTimer(expected_generation, expected_timer_id))
      if generation == expected_generation
      && timer_id == expected_timer_id
      && next_generation == expected_generation
    -> #(
      model.Model(
        ..model,
        phase: model.Connecting(next_generation, attempt),
        reconnect_timer: None,
      ),
      [OpenSocket(next_generation)],
    )
    _, _ -> #(model, [])
  }
}

fn retry_requested(model: Model) -> #(Model, List(Command)) {
  case model.phase, model.reconnect_timer {
    model.WaitingToReconnect(next_generation, attempt, _), Some(timer) ->
      manual_retry(model, next_generation, attempt, timer)
    model.Connecting(generation, _), _ -> manual_retry_active(model, generation)
    model.AwaitingRoomState(generation, _), _ ->
      manual_retry_active(model, generation)
    model.Joined(generation, _), _ -> manual_retry_active(model, generation)
    model.Blocked(_), _ -> manual_retry_without_timer(model)
    _, _ -> #(model, [])
  }
}

fn manual_retry(
  model: Model,
  next_generation: Int,
  attempt: Int,
  timer: model.ReconnectTimer,
) -> #(Model, List(Command)) {
  let updated =
    model.Model(
      ..model,
      phase: model.Connecting(next_generation, attempt),
      socket_generation: next_generation,
      reconnect_timer: None,
      feedback: None,
      connection_feedback: None,
    )
  #(updated, [
    CancelReconnect(timer.generation, timer.timer_id),
    OpenSocket(next_generation),
  ])
}

fn manual_retry_active(
  model: Model,
  generation: Int,
) -> #(Model, List(Command)) {
  let next_generation = model.socket_generation + 1
  let updated =
    model.Model(
      ..model,
      phase: model.Connecting(next_generation, model.reconnect_attempt),
      socket_generation: next_generation,
      reconnect_timer: None,
      room_snapshot: mark_snapshot_stale(model.room_snapshot),
      send_in_flight: None,
      rate_limit_until: None,
      feedback: None,
      connection_feedback: None,
    )
  let commands =
    cancel_reconnect(model)
    |> list.append(cancel_rate_limit_for_model(model))
    |> list.append([CloseSocket(generation), OpenSocket(next_generation)])
  #(updated, commands)
}

fn manual_retry_without_timer(model: Model) -> #(Model, List(Command)) {
  let generation = model.socket_generation + 1
  let updated =
    model.Model(
      ..model,
      phase: model.Connecting(generation, model.reconnect_attempt),
      socket_generation: generation,
      reconnect_timer: None,
      feedback: None,
      connection_feedback: None,
    )
  #(updated, [OpenSocket(generation)])
}

fn return_to_username(model: Model) -> #(Model, List(Command)) {
  let updated =
    model.Model(
      ..model,
      phase: model.ChoosingUsername,
      room_snapshot: None,
      send_in_flight: None,
      reconnect_timer: None,
      rate_limit_until: None,
      feedback: None,
      connection_feedback: None,
    )
  let commands = case model.phase {
    model.Connecting(generation, _)
    | model.AwaitingRoomState(generation, _)
    | model.Joined(generation, _) -> [CloseSocket(generation)]
    _ -> []
  }
  let commands =
    cancel_reconnect(model)
    |> list.append(commands)
    |> list.append(cancel_rate_limit_for_model(model))
    |> list.append([FocusUsername])
  #(updated, commands)
}

fn cancel_reconnect(model: Model) -> List(Command) {
  case model.reconnect_timer {
    Some(timer) -> [CancelReconnect(timer.generation, timer.timer_id)]
    None -> []
  }
}

fn cancel_rate_limit_for_model(model: Model) -> List(Command) {
  case model.rate_limit_until {
    Some(deadline_ms) ->
      case current_phase_generation(model.phase) {
        Some(generation) -> [CancelRateLimit(generation, deadline_ms)]
        None -> []
      }
    None -> []
  }
}

fn is_current_generation(
  phase: model.ConnectionPhase,
  generation: Int,
) -> Bool {
  case phase {
    model.Connecting(expected, _) -> expected == generation
    model.AwaitingRoomState(expected, _) -> expected == generation
    model.Joined(expected, _) -> expected == generation
    _ -> False
  }
}

fn mark_snapshot_stale(
  snapshot: Option(model.RoomSnapshot),
) -> Option(model.RoomSnapshot) {
  case snapshot {
    Some(value) -> Some(model.RoomSnapshot(..value, stale: True))
    None -> None
  }
}

fn upsert_presence(
  participants: List(domain.Presence),
  replacement: domain.Presence,
) -> List(domain.Presence) {
  case participants {
    [] -> [replacement]
    [first, ..rest] if first.connection_id == replacement.connection_id -> [
      replacement,
      ..remove_presence(rest, replacement.connection_id)
    ]
    [first, ..rest] -> [first, ..upsert_presence(rest, replacement)]
  }
}

fn remove_presence(
  participants: List(domain.Presence),
  connection_id: domain.ConnectionId,
) -> List(domain.Presence) {
  case participants {
    [] -> []
    [first, ..rest] if first.connection_id == connection_id ->
      remove_presence(rest, connection_id)
    [first, ..rest] -> [first, ..remove_presence(rest, connection_id)]
  }
}

fn has_presence_id(
  participants: List(domain.Presence),
  connection_id: domain.ConnectionId,
) -> Bool {
  case participants {
    [] -> False
    [first, ..] if first.connection_id == connection_id -> True
    [_, ..rest] -> has_presence_id(rest, connection_id)
  }
}

fn snapshot_participants_are_valid(
  participants: List(domain.Presence),
  self_id: domain.ConnectionId,
) -> Bool {
  has_presence_id(participants, self_id)
  && has_unique_presence_ids(participants, [])
}

fn has_unique_presence_ids(
  participants: List(domain.Presence),
  seen: List(domain.ConnectionId),
) -> Bool {
  case participants {
    [] -> True
    [first, ..rest] ->
      case list.contains(seen, first.connection_id) {
        True -> False
        False -> has_unique_presence_ids(rest, [first.connection_id, ..seen])
      }
  }
}
