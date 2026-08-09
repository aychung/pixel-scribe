import gleam/erlang/process.{type Monitor, type Pid, type Subject}
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

type RoomCommand {
  Join(username: domain.Username, sink: ConnectionSink)
  SendMessage(connection_id: domain.ConnectionId, text: domain.MessageText)
  Leave(connection_id: domain.ConnectionId)
  MemberDown(pid: Pid)
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
    members: List(RoomMember),
    messages: List(domain.ChatMessage),
  )
}

type RoomMember {
  RoomMember(
    connection_id: domain.ConnectionId,
    username: domain.Username,
    sink: ConnectionSink,
    monitor: Monitor,
  )
}

pub fn start(room_id: domain.RoomId) -> Result(Room, actor.StartError) {
  actor.new_with_initialiser(1000, fn(subject) {
    let selector =
      process.new_selector()
      |> process.select(subject)
      |> process.select_monitors(down_to_command)

    actor.initialised(State(room_id, [], []))
    |> actor.selecting(selector)
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
  sink: ConnectionSink,
) -> Nil {
  process.send(room.subject, Join(username, sink))
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

fn handle_message(
  state: State,
  command: RoomCommand,
) -> actor.Next(State, RoomCommand) {
  case command {
    Join(username, sink) -> handle_join(state, username, sink)
    SendMessage(connection_id, text) ->
      handle_send_message(state, connection_id, text)
    Leave(connection_id) -> handle_leave(state, connection_id)
    MemberDown(pid) -> handle_member_down(state, pid)
  }
}

fn handle_join(
  state: State,
  username: domain.Username,
  sink: ConnectionSink,
) -> actor.Next(State, RoomCommand) {
  case list.length(state.members) >= max_connections {
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
          let member = RoomMember(connection_id, username, sink, monitor)
          let members = list.append(state.members, [member])
          let users = list.map(members, member_to_presence)

          process.send(
            sink.subject,
            Joined(state.room_id, connection_id, users, state.messages),
          )
          broadcast(
            state.members,
            UserJoined(state.room_id, domain.Presence(connection_id, username)),
          )

          actor.continue(State(state.room_id, members, state.messages))
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
  case
    list.find(state.members, fn(member) {
      member.connection_id == connection_id
    })
  {
    Error(Nil) -> actor.continue(state)
    Ok(member) -> {
      let message =
        domain.ChatMessage(
          domain.new_message_id(),
          connection_id,
          member.username,
          text,
          domain.new_sent_at(),
        )
      let messages = append_message(state.messages, message)
      broadcast(state.members, MessageSent(state.room_id, message))
      actor.continue(State(state.room_id, state.members, messages))
    }
  }
}

fn handle_leave(
  state: State,
  connection_id: domain.ConnectionId,
) -> actor.Next(State, RoomCommand) {
  remove_matching_members(state, fn(member) {
    member.connection_id == connection_id
  })
}

fn handle_member_down(
  state: State,
  pid: Pid,
) -> actor.Next(State, RoomCommand) {
  remove_matching_members(state, fn(member) { member.sink.pid == pid })
}

fn down_to_command(down: process.Down) -> RoomCommand {
  case down {
    process.ProcessDown(_, pid, _) -> MemberDown(pid)
    process.PortDown(_, _, _) -> MemberDown(process.self())
  }
}

fn broadcast(members: List(RoomMember), event: RoomEvent) -> Nil {
  list.each(members, fn(member) { process.send(member.sink.subject, event) })
}

fn member_to_presence(member: RoomMember) -> domain.Presence {
  domain.Presence(member.connection_id, member.username)
}

fn remove_matching_members(
  state: State,
  should_remove: fn(RoomMember) -> Bool,
) -> actor.Next(State, RoomCommand) {
  let #(removed, remaining) = list.partition(state.members, should_remove)

  case removed {
    [] -> actor.continue(state)
    _ -> {
      list.each(removed, fn(member) {
        process.demonitor_process(member.monitor)
      })
      list.each(removed, fn(member) {
        broadcast(remaining, UserLeft(state.room_id, member.connection_id))
      })
      actor.continue(State(state.room_id, remaining, state.messages))
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
