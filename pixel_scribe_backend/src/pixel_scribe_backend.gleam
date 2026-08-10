import gleam/erlang/process
import pixel_scribe_backend/supervisor as application_supervisor

pub fn main() {
  let assert Ok(_supervisor) =
    application_supervisor.start(4000, "development-secret-key")
  process.sleep_forever()
}
