import lustre/effect.{type Effect}
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/model.{type Model}

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

/// The pure transition seam used by state-machine work. Task 4A only adds the
/// local username-input transition; later units fill in connection behavior.
pub fn transition(model: Model, message: Msg) -> #(Model, List(Command)) {
  case message {
    UsernameInput(value) -> #(model.Model(..model, username_input: value), [])
    _ -> #(model, [])
  }
}

/// Lustre's application callback remains effect-shaped while the state machine
/// is being introduced. Command interpretation is deliberately empty until the
/// browser-effect units provide its boundary implementation.
pub fn update(model: Model, message: Msg) -> #(Model, Effect(Msg)) {
  let #(updated, _commands) = transition(model, message)
  #(updated, effect.none())
}
