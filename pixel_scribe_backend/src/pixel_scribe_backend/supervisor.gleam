import gleam/otp/actor
import gleam/otp/static_supervisor
import gleam/otp/supervision.{type ChildSpecification, supervisor}
import pixel_scribe_backend/config
import pixel_scribe_backend/room_directory
import pixel_scribe_backend/room_factory
import pixel_scribe_backend/web

/// The validated values needed to wire the application supervisor to Wisp.
///
/// This intentionally contains no user-facing or durable configuration. The
/// Wisp key is generated in memory for the lifetime of one server process.
pub opaque type StartupConfiguration {
  StartupConfiguration(
    port: Int,
    secret_key_base: String,
    static_directory: String,
    development_origins: List(String),
  )
}

/// Construct the startup configuration accepted by the supervision tree.
///
/// Port `0` is accepted for ephemeral listeners, which keeps supervised tests
/// independent of a fixed local port. The production entry point uses the
/// configured port or its safe default instead.
pub fn startup_configuration(
  port: Int,
  secret_key_base: String,
) -> Result(StartupConfiguration, Nil) {
  case port >= 0 && port <= 65_535 && secret_key_base != "" {
    True ->
      Ok(
        StartupConfiguration(
          port:,
          secret_key_base:,
          static_directory: "priv/public",
          development_origins: [],
        ),
      )
    False -> Error(Nil)
  }
}

pub fn startup_configuration_from_config(
  configuration: config.Config,
) -> StartupConfiguration {
  StartupConfiguration(
    port: config.port(configuration),
    secret_key_base: config.secret_key_base(configuration),
    static_directory: config.static_directory(configuration),
    development_origins: config.development_origins(configuration),
  )
}

/// Start the application from already validated startup configuration.
pub fn start_with_configuration(
  configuration: StartupConfiguration,
) -> actor.StartResult(static_supervisor.Supervisor) {
  let StartupConfiguration(port, secret_key_base, static_directory, origins) =
    configuration
  start_tree(port, secret_key_base, static_directory, origins)
}

/// Compatibility wrapper for supervised tests and existing callers.
pub fn start(
  port: Int,
  secret_key_base: String,
) -> actor.StartResult(static_supervisor.Supervisor) {
  case startup_configuration(port, secret_key_base) {
    Ok(configuration) -> start_with_configuration(configuration)
    Error(Nil) -> Error(actor.InitFailed("invalid startup configuration"))
  }
}

fn start_tree(
  port: Int,
  secret_key_base: String,
  static_directory: String,
  development_origins: List(String),
) -> actor.StartResult(static_supervisor.Supervisor) {
  let directory_name = room_directory.new_name()
  let factory_name = room_factory.new_name()
  let directory = room_directory.from_name(directory_name)

  static_supervisor.new(static_supervisor.RestForOne)
  |> static_supervisor.add(room_directory.supervised(directory_name))
  |> static_supervisor.add(room_factory.supervised(directory, factory_name))
  |> static_supervisor.add(web.supervised_with_options(
    port,
    secret_key_base,
    directory,
    static_directory,
    development_origins,
  ))
  |> static_supervisor.start
}

pub fn supervised(
  port: Int,
  secret_key_base: String,
) -> ChildSpecification(static_supervisor.Supervisor) {
  supervisor(fn() { start(port, secret_key_base) })
}

/// Add a validated application supervisor to another supervision tree.
pub fn supervised_with_configuration(
  configuration: StartupConfiguration,
) -> ChildSpecification(static_supervisor.Supervisor) {
  supervisor(fn() { start_with_configuration(configuration) })
}
