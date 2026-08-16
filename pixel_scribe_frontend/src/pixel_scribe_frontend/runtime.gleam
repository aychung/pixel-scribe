import gleam/list
import gleam/option.{None, Some}
import lustre/effect.{type Effect}
import pixel_scribe_frontend/browser
import pixel_scribe_frontend/canvas
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/model.{type Model}
import pixel_scribe_frontend/protocol
import pixel_scribe_frontend/socket
import pixel_scribe_frontend/update

/// Connects the pure application transition to browser effects.
///
/// The reducer stays independent of Lustre and native browser handles. This
/// module is the only place that interprets commands or turns socket facts
/// into trusted application messages.
pub fn update(
  model: Model,
  message: update.Msg,
) -> #(Model, Effect(update.Msg)) {
  let #(updated, commands) = update.transition(model, message)
  let command_effect = interpret_commands(commands)
  let canvas_effect = canvas_lifecycle(model, updated)
  let scene_effect = scene_lifecycle(model, updated)
  #(updated, effect.batch([command_effect, canvas_effect, scene_effect]))
}

fn canvas_lifecycle(before: Model, after: Model) -> Effect(update.Msg) {
  case canvas_visible(before), canvas_visible(after) {
    False, True -> effect.map(canvas.initialize(), canvas_fact_to_msg)
    True, False -> canvas.dispose()
    _, _ -> effect.none()
  }
}

fn canvas_visible(model: Model) -> Bool {
  case model.room_snapshot {
    Some(_) -> True
    None -> False
  }
}

fn scene_lifecycle(before: Model, after: Model) -> Effect(update.Msg) {
  case before.room_snapshot, after.room_snapshot {
    Some(_), Some(_) if before.scene != after.scene ->
      render_current_scene(after)
    _, _ -> effect.none()
  }
}

fn render_current_scene(model: Model) -> Effect(update.Msg) {
  case model.scene {
    model.Ready(_, _, _, data, Some(camera), _) ->
      effect.map(canvas.render(data, camera), canvas_fact_to_msg)
    model.Placeholder | model.Failed(_) -> effect.none()
    model.Ready(_, _, _, _, None, _) -> effect.none()
  }
}

fn interpret_commands(commands: List(update.Command)) -> Effect(update.Msg) {
  commands
  |> list.map(interpret_command)
  |> effect.batch
}

fn interpret_command(command: update.Command) -> Effect(update.Msg) {
  case command {
    update.OpenSocket(generation) ->
      effect.map(socket.open(generation), socket_fact_to_msg)
    update.CloseSocket(generation) -> socket.close(generation)
    update.SendSocketFrame(generation, frame) -> socket.send(generation, frame)
    update.WriteUsernamePreference(username) ->
      effect.from(fn(_dispatch) { browser.write_username_preference(username) })
    update.ScheduleReconnect(generation, timer_id, delay_ms) ->
      browser.schedule_timer(
        browser.Reconnect,
        generation,
        timer_id,
        delay_ms,
        update.ReconnectTimerFired,
      )
    update.CancelReconnect(generation, timer_id) ->
      browser.cancel_timer(browser.Reconnect, generation, timer_id)
    update.ScheduleRateLimit(generation, deadline_ms, delay_ms) ->
      browser.schedule_timer(
        browser.RateLimit,
        generation,
        deadline_ms,
        delay_ms,
        update.RateLimitTimerFired,
      )
    update.CancelRateLimit(generation, deadline_ms) ->
      browser.cancel_timer(browser.RateLimit, generation, deadline_ms)
    update.FocusUsername -> browser.focus_username()
    update.FocusComposer -> browser.focus_composer()
    update.ScrollChatToEnd -> browser.scroll_chat_to_end()
    update.RenderScene(data, camera) ->
      effect.map(canvas.render(data, camera), canvas_fact_to_msg)
  }
}

fn canvas_fact_to_msg(fact: canvas.Fact) -> update.Msg {
  case fact {
    canvas.Ready(width, height, dpr) -> update.CanvasReady(width, height, dpr)
    canvas.Resized(width, height, dpr) ->
      update.CanvasResized(width, height, dpr)
    canvas.Failed(reason) -> update.CanvasFailed(reason)
  }
}

/// Decodes socket text at the transport boundary before dispatching it to the
/// reducer. Unknown event types are safe payload-free values; malformed frames
/// and binary frames fail closed as generation-scoped protocol messages.
pub fn socket_fact_to_msg(fact: socket.Fact) -> update.Msg {
  case fact {
    socket.Opened(generation) -> update.SocketOpened(generation)
    socket.Message(generation, received_at_ms, payload) ->
      case protocol.decode_server_event(payload) {
        Ok(domain.MessageSent(room_id, message)) ->
          update.AcceptedMessage(
            generation,
            room_id,
            message,
            browser.chat_log_near_bottom(),
          )
        Ok(event) -> update.ServerEvent(generation, received_at_ms, event)
        Error(_) -> update.ServerDecodeFailed(generation)
      }
    socket.NonTextFrame(generation) -> update.ServerDecodeFailed(generation)
    socket.Error(generation, random_unit) ->
      update.SocketError(generation, random_unit)
    socket.Closed(generation, deliberate, random_unit) ->
      update.SocketClosed(generation, deliberate, random_unit)
  }
}
