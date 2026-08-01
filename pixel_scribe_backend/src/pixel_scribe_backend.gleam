import gleam/erlang/process
import logging
import pixel_scribe_backend/config
import pixel_scribe_backend/supervisor

pub fn main() {
  logging.configure()
  logging.set_level(logging.Debug)
  let assert Ok(conf) = config.load()
  let assert Ok(_) = supervisor.start(conf)
  process.sleep_forever()
}
