import gleam/otp/actor
import gleam/otp/static_supervisor
import gleam/otp/supervision.{type ChildSpecification, supervisor}
import pixel_scribe_backend/room_directory
import pixel_scribe_backend/room_factory
import pixel_scribe_backend/web

pub fn start(
  port: Int,
  secret_key_base: String,
) -> actor.StartResult(static_supervisor.Supervisor) {
  let directory_name = room_directory.new_name()
  let factory_name = room_factory.new_name()
  let directory = room_directory.from_name(directory_name)

  static_supervisor.new(static_supervisor.RestForOne)
  |> static_supervisor.add(room_directory.supervised(directory_name))
  |> static_supervisor.add(room_factory.supervised(directory, factory_name))
  |> static_supervisor.add(web.supervised(port, secret_key_base))
  |> static_supervisor.start
}

pub fn supervised(
  port: Int,
  secret_key_base: String,
) -> ChildSpecification(static_supervisor.Supervisor) {
  supervisor(fn() { start(port, secret_key_base) })
}
