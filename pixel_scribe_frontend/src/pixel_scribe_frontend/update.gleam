import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/effect.{type Effect}
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/model.{type Model}
import pixel_scribe_frontend/protocol
import pixel_scribe_frontend/validation

/// Trusted application inputs and decoded server events. Raw browser payloads
/// are intentionally absent: protocol decoding happens before ServerEvent.
pub type Msg {
  UsernameInput(value: String)
  SubmitUsername
  DraftInput(value: String)
  SubmitMessage
  SocketOpened(generation: Int)
  SocketClosed(generation: Int, deliberate: Bool)
  SocketError(generation: Int)
  ServerEvent(generation: Int, event: domain.ServerEvent)
  ReconnectTimerFired(generation: Int, timer_id: Int)
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
  FocusUsername
  FocusComposer
  ScrollChatToEnd
  RenderScene
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
    SocketClosed(generation, _) -> socket_closed(model, generation)
    ServerEvent(generation, event) -> server_event(model, generation, event)
    _ -> #(model, [])
  }
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
  event: domain.ServerEvent,
) -> #(Model, List(Command)) {
  case event {
    domain.RoomState(room_id, self_id, users, messages) ->
      case model.phase {
        model.AwaitingRoomState(expected_generation, _)
          if expected_generation == generation
          && room_id == domain.default_room_id
        -> {
          let snapshot =
            model.RoomSnapshot(
              room_id,
              self_id,
              users,
              latest_unique_messages(messages),
              False,
            )
          #(
            model.Model(
              ..model,
              phase: model.Joined(generation, self_id),
              room_snapshot: Some(snapshot),
              reconnect_attempt: 0,
              connection_feedback: None,
            ),
            [],
          )
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
          #(model.Model(..model, room_snapshot: Some(updated_snapshot)), [])
        }
        _, _ -> #(model, [])
      }
    domain.UserLeft(room_id, connection_id) ->
      case model.phase, model.room_snapshot {
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
          #(model.Model(..model, room_snapshot: Some(updated_snapshot)), [])
        }
        _, _ -> #(model, [])
      }
    domain.MessageSent(room_id, message) ->
      accepted_message(model, generation, room_id, message)
    _ -> #(model, [])
  }
}

fn accepted_message(
  model: Model,
  generation: Int,
  room_id: domain.RoomId,
  message: domain.ChatMessage,
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
          #(
            model.Model(
              ..model,
              room_snapshot: Some(updated_snapshot),
              draft: draft,
              send_in_flight: send_in_flight,
            ),
            [],
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

fn socket_closed(model: Model, generation: Int) -> #(Model, List(Command)) {
  case is_current_generation(model.phase, generation) {
    False -> #(model, [])
    True -> #(
      model.Model(
        ..model,
        room_snapshot: mark_snapshot_stale(model.room_snapshot),
        send_in_flight: None,
      ),
      [],
    )
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
      ..rest
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
    [first, ..rest] if first.connection_id == connection_id -> rest
    [first, ..rest] -> [first, ..remove_presence(rest, connection_id)]
  }
}

/// Lustre's application callback remains effect-shaped while the state machine
/// is being introduced. Command interpretation is deliberately empty until the
/// browser-effect units provide its boundary implementation.
pub fn update(model: Model, message: Msg) -> #(Model, Effect(Msg)) {
  let #(updated, _commands) = transition(model, message)
  #(updated, effect.none())
}
