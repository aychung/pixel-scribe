import gleam/erlang/process.{type Pid, type Subject}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/option.{type Option, None, Some}
import mist
import pixel_scribe_backend/domain
import pixel_scribe_backend/protocol
import pixel_scribe_backend/room
import pixel_scribe_backend/room_directory

pub type Phase {
  AwaitingJoin
  Joining(room_id: domain.RoomId)
  Joined(room_id: domain.RoomId, connection_id: domain.ConnectionId)
}

pub type Action {
  ResolveRoom(room_id: domain.RoomId, username: domain.Username)
  Emit(event: protocol.ServerEvent)
  ReplyError(
    room_id: Option(domain.RoomId),
    code: protocol.ErrorCode,
    close: Bool,
  )
  Ignore
}

pub type Transition {
  Transition(phase: Phase, action: Action)
}

type ConnectionControl {
  FromRoom(event: room.RoomEvent)
  JoinedRoomDown(pid: Pid)
}

type State {
  State(
    directory: room_directory.RoomDirectory,
    room_events: Subject(room.RoomEvent),
    phase: Phase,
    room: Option(room.Room),
  )
}

pub fn handle_client_frame(
  phase: Phase,
  frame: protocol.ClientFrame,
) -> Transition {
  case protocol.decode_client_event_with_context(frame) {
    Error(protocol.DecodeFailure(error, room_id)) -> {
      let code = protocol.decode_error_to_error_code(error)
      error_transition(phase, room_id, code)
    }
    Ok(event) -> handle_client_event(phase, event)
  }
}

pub fn handle_room_event(phase: Phase, event: room.RoomEvent) -> Transition {
  case phase, event {
    Joining(expected_room_id),
      room.Joined(room_id, connection_id, users, messages)
      if expected_room_id == room_id
    ->
      Transition(
        Joined(room_id, connection_id),
        Emit(protocol.RoomState(room_id, connection_id, users, messages)),
      )
    Joining(expected_room_id), room.JoinRejected(room_id, room.RoomFull)
      if expected_room_id == room_id
    -> error_transition(phase, Some(room_id), protocol.RoomFull)
    Joined(expected_room_id, _), room.UserJoined(room_id, user)
      if expected_room_id == room_id
    -> Transition(phase, Emit(protocol.UserJoined(room_id, user)))
    Joined(expected_room_id, _), room.UserLeft(room_id, connection_id)
      if expected_room_id == room_id
    -> Transition(phase, Emit(protocol.UserLeft(room_id, connection_id)))
    Joined(expected_room_id, _), room.MessageSent(room_id, message)
      if expected_room_id == room_id
    -> Transition(phase, Emit(protocol.MessageSent(room_id, message)))
    _, _ -> Transition(phase, Ignore)
  }
}

pub fn handle_room_down(phase: Phase) -> Transition {
  case phase {
    AwaitingJoin -> Transition(phase, Ignore)
    Joining(room_id) | Joined(room_id, _) ->
      error_transition(phase, Some(room_id), protocol.RoomUnavailable)
  }
}

pub fn websocket(
  request: Request(mist.Connection),
  directory: room_directory.RoomDirectory,
) -> Response(mist.ResponseData) {
  mist.websocket(
    request: request,
    on_init: fn(_connection) {
      let room_events = process.new_subject()
      let selector =
        process.new_selector()
        |> process.select_map(room_events, FromRoom)
        |> process.select_monitors(down_to_control)
      #(State(directory, room_events, AwaitingJoin, None), Some(selector))
    },
    handler: handle_websocket_message,
    on_close: close,
  )
}

fn handle_websocket_message(
  state: State,
  message: mist.WebsocketMessage(ConnectionControl),
  websocket: mist.WebsocketConnection,
) -> mist.Next(State, ConnectionControl) {
  case message {
    mist.Text(payload) ->
      apply_transition(
        state,
        handle_client_frame(state.phase, protocol.TextFrame(payload)),
        websocket,
      )
    mist.Binary(payload) ->
      apply_transition(
        state,
        handle_client_frame(state.phase, protocol.BinaryFrame(payload)),
        websocket,
      )
    mist.Custom(control) -> handle_control(state, control, websocket)
    mist.Closed | mist.Shutdown -> mist.stop()
  }
}

fn handle_control(
  state: State,
  control: ConnectionControl,
  websocket: mist.WebsocketConnection,
) -> mist.Next(State, ConnectionControl) {
  case control {
    FromRoom(event) ->
      apply_transition(state, handle_room_event(state.phase, event), websocket)
    JoinedRoomDown(pid) ->
      case state.room {
        Some(room_handle) ->
          case room.pid(room_handle) == pid {
            True ->
              apply_transition(
                State(..state, room: None),
                handle_room_down(state.phase),
                websocket,
              )
            False -> mist.continue(state)
          }
        None -> mist.continue(state)
      }
  }
}

fn apply_transition(
  state: State,
  transition: Transition,
  websocket: mist.WebsocketConnection,
) -> mist.Next(State, ConnectionControl) {
  let Transition(phase, action) = transition
  let state = State(..state, phase: phase)

  case action {
    ResolveRoom(room_id, username) ->
      resolve_and_join(state, room_id, username, websocket)
    Emit(event) -> {
      send_event(websocket, event)
      mist.continue(state)
    }
    ReplyError(room_id, code, close) -> {
      send_event(websocket, protocol.ErrorEvent(room_id, code))
      case close {
        True -> mist.stop()
        False -> mist.continue(state)
      }
    }
    Ignore -> mist.continue(state)
  }
}

fn resolve_and_join(
  state: State,
  room_id: domain.RoomId,
  username: domain.Username,
  websocket: mist.WebsocketConnection,
) -> mist.Next(State, ConnectionControl) {
  case room_directory.resolve(state.directory, room_id) {
    Error(room_directory.RoomNotFound) -> {
      let transition =
        error_transition(AwaitingJoin, Some(room_id), protocol.RoomNotFound)
      apply_transition(state, transition, websocket)
    }
    Ok(room_handle) ->
      case process.is_alive(room.pid(room_handle)) {
        False -> {
          let transition =
            error_transition(
              AwaitingJoin,
              Some(room_id),
              protocol.RoomUnavailable,
            )
          apply_transition(state, transition, websocket)
        }
        True -> {
          let _monitor = process.monitor(room.pid(room_handle))
          let sink = room.new_connection_sink(state.room_events, process.self())
          room.join(room_handle, username, sink)
          mist.continue(State(..state, room: Some(room_handle)))
        }
      }
  }
}

fn send_event(
  websocket: mist.WebsocketConnection,
  event: protocol.ServerEvent,
) -> Nil {
  let _ = mist.send_text_frame(websocket, protocol.encode_server_event(event))
  Nil
}

fn close(state: State) -> Nil {
  case state.phase, state.room {
    Joined(_, connection_id), Some(room_handle) ->
      room.leave(room_handle, connection_id)
    _, _ -> Nil
  }
}

fn handle_client_event(
  phase: Phase,
  event: protocol.ClientEvent,
) -> Transition {
  case event {
    protocol.JoinRoom(room_id, username) ->
      case phase {
        AwaitingJoin ->
          Transition(Joining(room_id), ResolveRoom(room_id, username))
        _ -> error_transition(phase, Some(room_id), protocol.AlreadyJoined)
      }
    protocol.SendMessage(room_id, _) ->
      case phase {
        Joined(joined_room_id, _) ->
          case joined_room_id == room_id {
            True -> Transition(phase, Ignore)
            False ->
              error_transition(phase, Some(room_id), protocol.RoomMismatch)
          }
        AwaitingJoin | Joining(_) ->
          error_transition(phase, Some(room_id), protocol.JoinRequired)
      }
  }
}

fn error_transition(
  phase: Phase,
  room_id: Option(domain.RoomId),
  code: protocol.ErrorCode,
) -> Transition {
  Transition(
    phase,
    ReplyError(room_id, code, !protocol.error_is_recoverable(code)),
  )
}

fn down_to_control(down: process.Down) -> ConnectionControl {
  case down {
    process.ProcessDown(_, pid, _) -> JoinedRoomDown(pid)
    process.PortDown(_, _, _) -> JoinedRoomDown(process.self())
  }
}
