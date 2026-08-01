import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor
import pixel_scribe_backend/config.{type Config}
import pixel_scribe_backend/user_registry
import pixel_scribe_backend/web/server as http_server

pub type Names {
  Names(user_registry: process.Name(user_registry.Message))
}

pub fn start(config: Config) {
  let names = Names(user_registry: process.new_name("user_registry"))

  supervisor.new(supervisor.RestForOne)
  |> supervisor.add(user_registry.supervised(names.user_registry))
  |> supervisor.add(http_server.new(
    config.bind_address,
    config.port,
    names.user_registry,
  ))
  |> supervisor.start
}
