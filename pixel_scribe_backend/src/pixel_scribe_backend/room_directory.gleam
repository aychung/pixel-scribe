import gleam/dict
import gleam/erlang/process.{type Pid, type Subject}
import gleam/otp/actor
import gleam/result
import pixel_scribe_backend/domain
import pixel_scribe_backend/room

pub opaque type RoomDirectory {
  RoomDirectory(subject: Subject(RoomDirectoryMessage))
}

type RoomDirectoryMessage {
  RegisterRoom(
    room: room.Room,
    reply_to: Subject(Result(Nil, RegisterRoomError)),
  )
  ResolveRoom(
    room_id: domain.RoomId,
    reply_to: Subject(Result(room.Room, ResolveRoomError)),
  )
  RoomDown(pid: Pid)
}

pub type ResolveRoomError {
  RoomNotFound
}

pub type RegisterRoomError {
  RoomAlreadyRegistered
}

type State {
  State(rooms: dict.Dict(domain.RoomId, room.Room))
}

pub fn start() -> Result(RoomDirectory, actor.StartError) {
  actor.new_with_initialiser(1000, fn(subject) {
    let selector =
      process.new_selector()
      |> process.select(subject)
      |> process.select_monitors(down_to_command)

    actor.initialised(State(dict.new()))
    |> actor.selecting(selector)
    |> actor.returning(subject)
    |> Ok
  })
  |> actor.on_message(handle_message)
  |> actor.start
  |> result.map(fn(started) { RoomDirectory(started.data) })
}

pub fn register(
  directory: RoomDirectory,
  room_handle: room.Room,
) -> Result(Nil, RegisterRoomError) {
  process.call(directory.subject, 1000, fn(reply_to) {
    RegisterRoom(room_handle, reply_to)
  })
}

pub fn resolve(
  directory: RoomDirectory,
  room_id: domain.RoomId,
) -> Result(room.Room, ResolveRoomError) {
  process.call(directory.subject, 1000, fn(reply_to) {
    ResolveRoom(room_id, reply_to)
  })
}

fn handle_message(
  state: State,
  message: RoomDirectoryMessage,
) -> actor.Next(State, RoomDirectoryMessage) {
  case message {
    RegisterRoom(room_handle, reply_to) ->
      handle_register(state, room_handle, reply_to)
    ResolveRoom(room_id, reply_to) -> handle_resolve(state, room_id, reply_to)
    RoomDown(pid) -> handle_room_down(state, pid)
  }
}

fn handle_register(
  state: State,
  room_handle: room.Room,
  reply_to: Subject(Result(Nil, RegisterRoomError)),
) -> actor.Next(State, RoomDirectoryMessage) {
  let room_id = room.room_id(room_handle)
  case can_register_room(state.rooms, room_id) {
    True -> register_room(state, room_id, room_handle, reply_to)
    False -> {
      process.send(reply_to, Error(RoomAlreadyRegistered))
      actor.continue(state)
    }
  }
}

@internal
pub fn can_register_room(
  rooms: dict.Dict(domain.RoomId, room.Room),
  room_id: domain.RoomId,
) -> Bool {
  case dict.get(rooms, room_id) {
    Error(_) -> True
    Ok(existing) -> !process.is_alive(room.pid(existing))
  }
}

fn register_room(
  state: State,
  room_id: domain.RoomId,
  room_handle: room.Room,
  reply_to: Subject(Result(Nil, RegisterRoomError)),
) -> actor.Next(State, RoomDirectoryMessage) {
  let _ = process.monitor(room.pid(room_handle))
  let rooms = dict.insert(state.rooms, for: room_id, insert: room_handle)
  process.send(reply_to, Ok(Nil))
  actor.continue(State(rooms))
}

fn handle_resolve(
  state: State,
  room_id: domain.RoomId,
  reply_to: Subject(Result(room.Room, ResolveRoomError)),
) -> actor.Next(State, RoomDirectoryMessage) {
  let result = case dict.get(state.rooms, room_id) {
    Ok(room_handle) -> Ok(room_handle)
    Error(_) -> Error(RoomNotFound)
  }
  process.send(reply_to, result)
  actor.continue(state)
}

fn handle_room_down(
  state: State,
  pid: Pid,
) -> actor.Next(State, RoomDirectoryMessage) {
  actor.continue(State(remove_room_for_down(state.rooms, pid)))
}

@internal
pub fn remove_room_for_down(
  rooms: dict.Dict(domain.RoomId, room.Room),
  pid: Pid,
) -> dict.Dict(domain.RoomId, room.Room) {
  dict.filter(rooms, keeping: fn(_, room_handle) {
    room.pid(room_handle) != pid
  })
}

fn down_to_command(down: process.Down) -> RoomDirectoryMessage {
  case down {
    process.ProcessDown(_, pid, _) -> RoomDown(pid)
    // This actor creates process monitors only, so this matches no room.
    process.PortDown(_, _, _) -> RoomDown(process.self())
  }
}
