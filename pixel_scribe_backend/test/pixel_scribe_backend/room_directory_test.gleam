import gleam/dict
import gleam/erlang/process
import pixel_scribe_backend/domain
import pixel_scribe_backend/room
import pixel_scribe_backend/room_directory

pub fn default_room_can_be_registered_and_resolved_test() {
  let assert Ok(directory) = room_directory.start()
  let assert Ok(default_room) = room.start(domain.default_room_id)

  assert room_directory.register(directory, default_room) == Ok(Nil)
  assert room_directory.resolve(directory, domain.default_room_id)
    == Ok(default_room)
}

pub fn unknown_rooms_return_room_not_found_test() {
  let assert Ok(directory) = room_directory.start()
  let assert Ok(room_id) = domain.new_room_id("other")

  assert room_directory.resolve(directory, room_id)
    == Error(room_directory.RoomNotFound)
}

pub fn live_duplicate_registration_is_rejected_test() {
  let assert Ok(directory) = room_directory.start()
  let assert Ok(default_room) = room.start(domain.default_room_id)
  let assert Ok(second_room) = room.start(domain.default_room_id)

  assert room_directory.register(directory, default_room) == Ok(Nil)
  assert room_directory.register(directory, second_room)
    == Error(room_directory.RoomAlreadyRegistered)
  assert room_directory.resolve(directory, domain.default_room_id)
    == Ok(default_room)
}

pub fn dead_room_registration_is_replaced_test() {
  let assert Ok(directory) = room_directory.start()
  let #(_, old_room) = new_remote_room()
  let #(_, replacement) = new_remote_room()

  assert room_directory.register(directory, old_room) == Ok(Nil)
  let old_monitor = process.monitor(room.pid(old_room))
  process.kill(room.pid(old_room))
  wait_for_process_down(old_monitor)

  assert room_directory.register(directory, replacement) == Ok(Nil)
  assert room_directory.resolve(directory, domain.default_room_id)
    == Ok(replacement)
}

pub fn dead_existing_room_is_admitted_for_replacement_test() {
  let #(_, old_room) = new_remote_room()
  let old_monitor = process.monitor(room.pid(old_room))
  process.kill(room.pid(old_room))
  wait_for_process_down(old_monitor)
  let rooms =
    dict.new()
    |> dict.insert(domain.default_room_id, old_room)

  assert room_directory.can_register_room(rooms, domain.default_room_id)
}

pub fn dead_rooms_are_removed_after_monitor_notification_test() {
  let assert Ok(directory) = room_directory.start()
  let #(_, registered_room) = new_remote_room()

  assert room_directory.register(directory, registered_room) == Ok(Nil)
  process.kill(room.pid(registered_room))

  wait_until_room_not_found(directory, 1000)
}

pub fn delayed_down_for_old_room_cannot_remove_replacement_test() {
  let assert Ok(old_room) = room.start(domain.default_room_id)
  let assert Ok(replacement) = room.start(domain.default_room_id)
  let rooms_after_replacement =
    dict.new()
    |> dict.insert(domain.default_room_id, replacement)

  let rooms_after_old_down =
    room_directory.remove_room_for_down(
      rooms_after_replacement,
      room.pid(old_room),
    )

  assert dict.get(rooms_after_old_down, domain.default_room_id)
    == Ok(replacement)
}

fn wait_for_process_down(monitor: process.Monitor) -> Nil {
  let selector =
    process.new_selector()
    |> process.select_specific_monitor(monitor, fn(down) { down })
  let assert Ok(process.ProcessDown(_, _, _)) =
    process.selector_receive(selector, 1000)
  Nil
}

fn wait_until_room_not_found(
  directory: room_directory.RoomDirectory,
  attempts: Int,
) -> Nil {
  case room_directory.resolve(directory, domain.default_room_id), attempts {
    Error(room_directory.RoomNotFound), _ -> Nil
    _, 0 -> panic as "dead room remained registered"
    _, _ -> {
      process.sleep(1)
      wait_until_room_not_found(directory, attempts - 1)
    }
  }
}

fn new_remote_room() -> #(process.Pid, room.Room) {
  let ready = process.new_subject()
  let owner =
    process.spawn_unlinked(fn() {
      let assert Ok(room_handle) = room.start(domain.default_room_id)
      process.send(ready, #(process.self(), room_handle))
      process.sleep_forever()
    })
  let assert Ok(#(room_owner, room_handle)) =
    process.receive(from: ready, within: 1000)
  assert room_owner == owner
  #(owner, room_handle)
}
