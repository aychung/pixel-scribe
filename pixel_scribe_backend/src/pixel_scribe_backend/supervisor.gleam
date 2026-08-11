import gleam/option.{type Option, None}
import gleam/otp/actor
import gleam/otp/static_supervisor
import gleam/otp/supervision.{type ChildSpecification, supervisor}
import pixel_scribe_backend/config
import pixel_scribe_backend/room_directory
import pixel_scribe_backend/room_factory
import pixel_scribe_backend/web
import wisp

/// The validated values needed to wire the application supervisor to Wisp.
///
/// This intentionally contains no user-facing or durable configuration. The
/// Wisp key is generated in memory for the lifetime of one server process.
pub opaque type StartupConfiguration {
  StartupConfiguration(
    port: Int,
    bind_address: String,
    static_directory: String,
    public_origin: Option(String),
    development_origins: List(String),
  )
}

/// Construct the startup configuration accepted by the supervision tree.
///
/// Port `0` is accepted for ephemeral listeners, which keeps supervised tests
/// independent of a fixed local port. The production entry point uses the
/// configured port or its safe default instead.
pub fn startup_configuration(port: Int) -> Result(StartupConfiguration, Nil) {
  startup_configuration_with_bind_address(port, "localhost")
}

pub fn startup_configuration_with_bind_address(
  port: Int,
  bind_address: String,
) -> Result(StartupConfiguration, Nil) {
  case port >= 0 && port <= 65_535 && config.valid_bind_address(bind_address) {
    True ->
      Ok(
        StartupConfiguration(
          port:,
          bind_address:,
          static_directory: "priv/public",
          public_origin: None,
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
    bind_address: config.bind_address(configuration),
    static_directory: config.static_directory(configuration),
    public_origin: config.public_origin(configuration),
    development_origins: config.development_origins(configuration),
  )
}

/// Start the application from already validated startup configuration.
pub fn start_with_configuration(
  configuration: StartupConfiguration,
) -> actor.StartResult(static_supervisor.Supervisor) {
  start_with_configuration_and_key(configuration, wisp.random_string(64))
}

fn start_with_configuration_and_key(
  configuration: StartupConfiguration,
  secret_key_base: String,
) -> actor.StartResult(static_supervisor.Supervisor) {
  let StartupConfiguration(
    port,
    bind_address,
    static_directory,
    public_origin,
    origins,
  ) = configuration
  start_tree(
    port,
    bind_address,
    secret_key_base,
    static_directory,
    public_origin,
    origins,
  )
}

/// Start with a caller-provided adapter key for deterministic server tests.
pub fn start(
  port: Int,
  secret_key_base: String,
) -> actor.StartResult(static_supervisor.Supervisor) {
  case startup_configuration(port) {
    Ok(configuration) ->
      start_with_configuration_and_key(configuration, secret_key_base)
    Error(Nil) -> Error(actor.InitFailed("invalid startup configuration"))
  }
}

fn start_tree(
  port: Int,
  bind_address: String,
  secret_key_base: String,
  static_directory: String,
  public_origin: Option(String),
  development_origins: List(String),
) -> actor.StartResult(static_supervisor.Supervisor) {
  let directory_name = room_directory.new_name()
  let factory_name = room_factory.new_name()
  let directory = room_directory.from_name(directory_name)

  static_supervisor.new(static_supervisor.RestForOne)
  |> static_supervisor.add(room_directory.supervised(directory_name))
  |> static_supervisor.add(room_factory.supervised(directory, factory_name))
  |> static_supervisor.add(web.supervised(
    port,
    bind_address,
    secret_key_base,
    directory,
    static_directory,
    public_origin,
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
