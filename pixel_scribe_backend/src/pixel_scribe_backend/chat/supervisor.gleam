import gleam/erlang/process.{type Name}
import gleam/otp/factory_supervisor
import pixel_scribe_backend/chat/room

pub fn start(name: Name(_)) {
  factory_supervisor.worker_child(room.new_actor)
  |> factory_supervisor.named(name)
  |> factory_supervisor.supervised
}
