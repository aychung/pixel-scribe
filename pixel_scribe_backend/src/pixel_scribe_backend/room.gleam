import gleam/erlang/process.{type Monitor, type Pid, type Selector, type Subject}
import gleam/list
import gleam/otp/actor
import gleam/result
import pixel_scribe_backend/domain

pub const max_connections = 50

pub const max_history = 50

pub opaque type Room {
  Room(room_id: domain.RoomId, subject: Subject(RoomCommand), pid: Pid)
}

pub opaque type ConnectionSink {
  ConnectionSink(subject: Subject(RoomEvent), pid: Pid)
}

pub type RoomCommand {
  Join(username: domain.Username, connection: ConnectionSink)
  SendMessage(connection_id: domain.ConnectionId, text: domain.MessageText)
  Leave(connection_id: domain.ConnectionId)
  ConnectionDown(pid: Pid)
}

pub type RoomEvent {
  Joined(
    room_id: domain.RoomId,
    self_id: domain.ConnectionId,
    users: List(domain.Presence),
    messages: List(domain.ChatMessage),
  )
  JoinRejected(room_id: domain.RoomId, error: RoomError)
  UserJoined(room_id: domain.RoomId, user: domain.Presence)
  UserLeft(room_id: domain.RoomId, connection_id: domain.ConnectionId)
  MessageSent(room_id: domain.RoomId, message: domain.ChatMessage)
}

pub type RoomError {
  RoomFull
}

type State {
  State(
    room_id: domain.RoomId,
    subject: Subject(RoomCommand),
    connections: List(Connection),
    messages: List(domain.ChatMessage),
  )
}

type Connection {
  Connection(
    connection_id: domain.ConnectionId,
    username: domain.Username,
    sink: ConnectionSink,
    pid: Pid,
    monitor: Monitor,
  )
}

pub fn start(room_id: domain.RoomId) -> Result(Room, actor.StartError) {
  actor.new_with_initialiser(1000, fn(subject) {
    actor.initialised(State(room_id, subject, [], []))
    |> actor.returning(subject)
    |> Ok
  })
  |> actor.on_message(handle_message)
  |> actor.start
  |> result.map(fn(started) { Room(room_id, started.data, started.pid) })
}

pub fn new_connection_sink(
  subject: Subject(RoomEvent),
  pid: Pid,
) -> ConnectionSink {
  ConnectionSink(subject, pid)
}

pub fn room_id(room: Room) -> domain.RoomId {
  room.room_id
}

pub fn pid(room: Room) -> Pid {
  room.pid
}

pub fn join(
  room: Room,
  username: domain.Username,
  connection: ConnectionSink,
) -> Nil {
  process.send(room.subject, Join(username, connection))
}

pub fn send_message(
  room: Room,
  connection_id: domain.ConnectionId,
  text: domain.MessageText,
) -> Nil {
  process.send(room.subject, SendMessage(connection_id, text))
}

pub fn leave(room: Room, connection_id: domain.ConnectionId) -> Nil {
  process.send(room.subject, Leave(connection_id))
}

pub fn connection_down(room: Room, pid: Pid) -> Nil {
  process.send(room.subject, ConnectionDown(pid))
}

fn handle_message(
  state: State,
  command: RoomCommand,
) -> actor.Next(State, RoomCommand) {
  case command {
    Join(username, connection) -> handle_join(state, username, connection)
    SendMessage(connection_id, text) ->
      handle_send_message(state, connection_id, text)
    Leave(connection_id) -> handle_leave(state, connection_id)
    ConnectionDown(pid) -> handle_connection_down(state, pid)
  }
}

fn handle_join(
  state: State,
  username: domain.Username,
  sink: ConnectionSink,
) -> actor.Next(State, RoomCommand) {
  case list.length(state.connections) >= max_connections {
    True -> {
      process.send(sink.subject, JoinRejected(state.room_id, RoomFull))
      actor.continue(state)
    }
    False -> {
      let connection_id = domain.new_connection_id()
      let monitor = process.monitor(sink.pid)
      case process.is_alive(sink.pid) {
        False -> {
          process.demonitor_process(monitor)
          actor.continue(state)
        }
        True -> {
          let connection =
            Connection(connection_id, username, sink, sink.pid, monitor)
          let connections = list.append(state.connections, [connection])
          let users = list.map(connections, connection_to_presence)

          process.send(
            sink.subject,
            Joined(state.room_id, connection_id, users, state.messages),
          )
          broadcast(
            state.connections,
            UserJoined(
              state.room_id,
              domain.new_presence(connection_id, username),
            ),
          )

          continue_with_selector(State(
            state.room_id,
            state.subject,
            connections,
            state.messages,
          ))
        }
      }
    }
  }
}

fn handle_send_message(
  state: State,
  connection_id: domain.ConnectionId,
  text: domain.MessageText,
) -> actor.Next(State, RoomCommand) {
  case find_connection(state.connections, connection_id) {
    Error(Nil) -> actor.continue(state)
    Ok(connection) -> {
      let message =
        domain.new_chat_message(
          domain.new_message_id(),
          connection_id,
          connection.username,
          text,
          domain.new_sent_at(),
        )
      let messages = append_message(state.messages, message)
      broadcast(state.connections, MessageSent(state.room_id, message))
      actor.continue(State(
        state.room_id,
        state.subject,
        state.connections,
        messages,
      ))
    }
  }
}

fn handle_leave(
  state: State,
  connection_id: domain.ConnectionId,
) -> actor.Next(State, RoomCommand) {
  let #(connections, removed) =
    remove_connection(state.connections, connection_id)

  case removed {
    Error(Nil) -> actor.continue(state)
    Ok(connection) -> {
      process.demonitor_process(connection.monitor)
      broadcast(connections, UserLeft(state.room_id, connection.connection_id))
      continue_with_selector(State(
        state.room_id,
        state.subject,
        connections,
        state.messages,
      ))
    }
  }
}

fn handle_connection_down(
  state: State,
  pid: Pid,
) -> actor.Next(State, RoomCommand) {
  let #(connections, removed) = remove_connections(state.connections, pid)

  case removed {
    [] -> actor.continue(state)
    _ -> {
      list.each(removed, fn(connection) {
        process.demonitor_process(connection.monitor)
      })
      list.each(removed, fn(connection) {
        broadcast(
          connections,
          UserLeft(state.room_id, connection.connection_id),
        )
      })
      continue_with_selector(State(
        state.room_id,
        state.subject,
        connections,
        state.messages,
      ))
    }
  }
}

fn continue_with_selector(state: State) -> actor.Next(State, RoomCommand) {
  let selector = connection_selector(state.subject, state.connections)
  actor.continue(state) |> actor.with_selector(selector)
}

fn connection_selector(
  subject: Subject(RoomCommand),
  connections: List(Connection),
) -> Selector(RoomCommand) {
  list.fold(
    connections,
    process.new_selector() |> process.select(subject),
    fn(selector, connection) {
      process.select_specific_monitor(
        selector,
        connection.monitor,
        down_to_command,
      )
    },
  )
}

fn down_to_command(down: process.Down) -> RoomCommand {
  case down {
    process.ProcessDown(_, pid, _) -> ConnectionDown(pid)
    process.PortDown(_, _, _) -> ConnectionDown(process.self())
  }
}

fn broadcast(connections: List(Connection), event: RoomEvent) -> Nil {
  list.each(connections, fn(connection) {
    process.send(connection.sink.subject, event)
  })
}

fn connection_to_presence(connection: Connection) -> domain.Presence {
  domain.new_presence(connection.connection_id, connection.username)
}

fn find_connection(
  connections: List(Connection),
  connection_id: domain.ConnectionId,
) -> Result(Connection, Nil) {
  case connections {
    [] -> Error(Nil)
    [connection, ..rest] ->
      case connection.connection_id == connection_id {
        True -> Ok(connection)
        False -> find_connection(rest, connection_id)
      }
  }
}

fn remove_connection(
  connections: List(Connection),
  connection_id: domain.ConnectionId,
) -> #(List(Connection), Result(Connection, Nil)) {
  case connections {
    [] -> #([], Error(Nil))
    [connection, ..rest] ->
      case connection.connection_id == connection_id {
        True -> #(rest, Ok(connection))
        False -> {
          let #(remaining, removed) = remove_connection(rest, connection_id)
          #([connection, ..remaining], removed)
        }
      }
  }
}

fn remove_connections(
  connections: List(Connection),
  pid: Pid,
) -> #(List(Connection), List(Connection)) {
  case connections {
    [] -> #([], [])
    [connection, ..rest] -> {
      let #(remaining, removed) = remove_connections(rest, pid)
      case connection.pid == pid {
        True -> #(remaining, [connection, ..removed])
        False -> #([connection, ..remaining], removed)
      }
    }
  }
}

fn append_message(
  messages: List(domain.ChatMessage),
  message: domain.ChatMessage,
) -> List(domain.ChatMessage) {
  let messages = list.append(messages, [message])
  let overflow = list.length(messages) - max_history

  case overflow > 0 {
    True -> list.drop(messages, overflow)
    False -> messages
  }
}
