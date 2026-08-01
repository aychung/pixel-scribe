import gleam/otp/static_supervisor as supervisor
import pixel_scribe_backend/config.{type Config}
import pixel_scribe_backend/web/server as http_server

pub fn start(config: Config) {
  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(http_server.new(config.port))
  |> supervisor.start
}
