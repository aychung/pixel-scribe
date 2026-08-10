import gleam/erlang/process
import pixel_scribe_backend/domain
import pixel_scribe_backend/room
import pixel_scribe_backend/room_directory
import pixel_scribe_backend/room_factory

pub fn startup_registers_default_before_returning_test() {
  let assert Ok(directory) = room_directory.start()
  let factory_name = room_factory.new_name()

  let assert Ok(_factory) = room_factory.start(directory, factory_name)
  let assert Ok(default_room) =
    room_directory.resolve(directory, domain.default_room_id)

  assert process.is_alive(room.pid(default_room))
}

pub fn failed_default_registration_fails_factory_start_test() {
  let assert Ok(directory) = room_directory.start()
  let assert Ok(existing_room) = room.start(domain.default_room_id)
  let assert Ok(Nil) = room_directory.register(directory, existing_room)
  let factory_name = room_factory.new_name()

  let assert Error(_) = room_factory.start(directory, factory_name)
  let existing_room_monitor = process.monitor(room.pid(existing_room))
  process.unlink(room.pid(existing_room))
  process.kill(room.pid(existing_room))
  wait_for_process_down(existing_room_monitor)
  let assert Ok(_factory) = room_factory.start(directory, factory_name)
  Nil
}

pub fn failed_room_is_replaced_with_the_same_arguments_test() {
  let assert Ok(directory) = room_directory.start()
  let factory_name = room_factory.new_name()
  let assert Ok(_factory) = room_factory.start(directory, factory_name)
  let assert Ok(old_room) =
    room_directory.resolve(directory, domain.default_room_id)

  let old_room_monitor = process.monitor(room.pid(old_room))
  process.kill(room.pid(old_room))
  wait_for_process_down(old_room_monitor)
  wait_for_replacement(directory, room.pid(old_room), 1000)
}

fn wait_for_process_down(monitor: process.Monitor) -> Nil {
  let selector =
    process.new_selector()
    |> process.select_specific_monitor(monitor, fn(down) { down })
  let assert Ok(process.ProcessDown(_, _, _)) =
    process.selector_receive(selector, 1000)
  Nil
}

fn wait_for_replacement(
  directory: room_directory.RoomDirectory,
  old_pid: process.Pid,
  retries_remaining: Int,
) -> Nil {
  let replacement_found = case
    room_directory.resolve(directory, domain.default_room_id)
  {
    Ok(new_room) -> room.pid(new_room) != old_pid
    Error(_) -> False
  }

  case replacement_found, retries_remaining {
    True, _ -> Nil
    False, 0 -> panic as "room was not replaced"
    False, _ -> {
      process.sleep(1)
      wait_for_replacement(directory, old_pid, retries_remaining - 1)
    }
  }
}
