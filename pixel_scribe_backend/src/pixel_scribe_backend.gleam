import gleam/erlang/process
import logging
import pixel_scribe_backend/config
import pixel_scribe_backend/supervisor as application_supervisor

pub fn main() {
  process.trap_exits(True)

  let assert Ok(configuration) = config.load()
  let configuration =
    application_supervisor.startup_configuration_from_config(configuration)
  let assert Ok(_supervisor) =
    application_supervisor.start_with_configuration(configuration)

  logging.configure()
  logging.log(logging.Info, "event=application_started")
  wait_for_application_shutdown()
}

fn wait_for_application_shutdown() -> Nil {
  let selector = process.new_selector()
  let selector =
    process.select_trapped_exits(selector, fn(_) {
      logging.log(logging.Info, "event=application_stopped")
      Nil
    })
  process.selector_receive_forever(selector)
  Nil
}
