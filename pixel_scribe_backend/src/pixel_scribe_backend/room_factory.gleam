import gleam/erlang/process
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/otp/factory_supervisor as factory
import gleam/otp/supervision.{type ChildSpecification, Transient, supervisor}
import pixel_scribe_backend/domain
import pixel_scribe_backend/lifecycle_logging
import pixel_scribe_backend/room
import pixel_scribe_backend/room_directory

pub opaque type RoomFactoryName {
  RoomFactoryName(process.Name(factory.Message(RoomStartArguments, room.Room)))
}

pub opaque type RoomFactory {
  RoomFactory(factory.Supervisor(RoomStartArguments, room.Room))
}

pub type RoomStartArguments {
  RoomStartArguments(
    room_id: domain.RoomId,
    directory: room_directory.RoomDirectory,
  )
}

pub fn new_name() -> RoomFactoryName {
  RoomFactoryName(process.new_name("room_factory"))
}

pub fn from_name(name: RoomFactoryName) -> RoomFactory {
  let RoomFactoryName(name) = name
  RoomFactory(factory.get_by_name(name))
}

pub fn start(
  directory: room_directory.RoomDirectory,
  name: RoomFactoryName,
) -> actor.StartResult(RoomFactory) {
  let RoomFactoryName(name) = name
  let builder =
    factory.worker_child(start_room)
    |> factory.named(name)
    |> factory.restart_strategy(Transient)

  case factory.start(builder) {
    Error(error) -> Error(error)
    Ok(started) -> {
      let arguments = RoomStartArguments(domain.default_room_id, directory)
      case factory.start_child(started.data, arguments) {
        Ok(_) ->
          Ok(actor.Started(pid: started.pid, data: RoomFactory(started.data)))
        Error(error) -> {
          stop_factory(started.pid)
          Error(error)
        }
      }
    }
  }
}

pub fn supervised(
  directory: room_directory.RoomDirectory,
  name: RoomFactoryName,
) -> ChildSpecification(RoomFactory) {
  supervisor(fn() { start(directory, name) })
}

pub fn start_child(
  room_factory: RoomFactory,
  arguments: RoomStartArguments,
) -> actor.StartResult(room.Room) {
  let RoomFactory(supervisor) = room_factory
  factory.start_child(supervisor, arguments)
}

fn start_room(arguments: RoomStartArguments) -> actor.StartResult(room.Room) {
  let RoomStartArguments(room_id, directory) = arguments
  case room.start(room_id) {
    Error(error) -> {
      lifecycle_logging.log(lifecycle_logging.RoomUnexpectedFailure(
        Some(room_id),
        None,
        None,
        lifecycle_logging.RoomStartFailed,
      ))
      Error(error)
    }
    Ok(room_handle) -> {
      case room_directory.register(directory, room_handle) {
        Ok(Nil) ->
          Ok(actor.Started(pid: room.pid(room_handle), data: room_handle))
        Error(_) -> {
          lifecycle_logging.log(lifecycle_logging.RoomUnexpectedFailure(
            Some(room_id),
            None,
            None,
            lifecycle_logging.RoomRegistrationFailed,
          ))
          process.unlink(room.pid(room_handle))
          process.kill(room.pid(room_handle))
          Error(actor.InitFailed("room registration failed"))
        }
      }
    }
  }
}

fn stop_factory(pid: process.Pid) -> Nil {
  let monitor = process.monitor(pid)
  process.unlink(pid)
  process.kill(pid)

  process.new_selector()
  |> process.select_specific_monitor(monitor, fn(_) { Nil })
  |> process.selector_receive_forever
}
