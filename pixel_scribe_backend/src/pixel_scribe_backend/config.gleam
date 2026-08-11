import envoy
import gleam/dynamic.{type Dynamic}
import gleam/erlang/charlist
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri.{Uri}

const default_port = 4000

const default_bind_address = "localhost"

const default_static_directory = "priv/public"

const default_development_origins = ["http://localhost:1234"]

pub type Environment {
  Development
  Production
}

pub opaque type Config {
  Config(
    port: Int,
    bind_address: String,
    static_directory: String,
    environment: Environment,
    development_origins: List(String),
    public_origin: Option(String),
  )
}

pub type Setting {
  Port
  BindAddress
  StaticDirectory
  Environment
  DevelopmentOrigins
  PublicOrigin
}

pub type ConfigError {
  Invalid(Setting)
}

pub fn load() -> Result(Config, ConfigError) {
  use port <- result.try(read_port())
  use bind_address <- result.try(read_bind_address())
  use static_directory <- result.try(read_static_directory())
  use environment <- result.try(read_environment())
  use public_origin <- result.try(read_public_origin())

  let default_origins = case environment {
    Development -> default_development_origins
    Production -> []
  }
  use development_origins <- result.try(read_development_origins(
    default_origins,
  ))

  case environment, development_origins {
    Production, [] | Development, _ ->
      Ok(Config(
        port:,
        bind_address:,
        static_directory:,
        environment:,
        development_origins:,
        public_origin:,
      ))
    Production, _ -> Error(Invalid(DevelopmentOrigins))
  }
}

pub fn port(config: Config) -> Int {
  config.port
}

pub fn bind_address(config: Config) -> String {
  config.bind_address
}

pub fn static_directory(config: Config) -> String {
  config.static_directory
}

pub fn environment(config: Config) -> Environment {
  config.environment
}

pub fn development_origins(config: Config) -> List(String) {
  config.development_origins
}

pub fn public_origin(config: Config) -> Option(String) {
  config.public_origin
}

fn read_port() -> Result(Int, ConfigError) {
  case envoy.get("PORT") {
    Error(Nil) -> Ok(default_port)
    Ok(value) ->
      case int.parse(string.trim(value)) {
        Ok(port) if port >= 1 && port <= 65_535 -> Ok(port)
        _ -> Error(Invalid(Port))
      }
  }
}

fn read_bind_address() -> Result(String, ConfigError) {
  let address = case envoy.get("HOST") {
    Error(Nil) -> default_bind_address
    Ok(value) -> string.trim(value)
  }

  case valid_bind_address(address) {
    True -> Ok(address)
    False -> Error(Invalid(BindAddress))
  }
}

fn read_static_directory() -> Result(String, ConfigError) {
  let path = case envoy.get("STATIC_DIRECTORY") {
    Error(Nil) -> default_static_directory
    Ok(value) -> string.trim(value)
  }

  case valid_static_directory(path) {
    True -> Ok(path)
    False -> Error(Invalid(StaticDirectory))
  }
}

fn read_environment() -> Result(Environment, ConfigError) {
  case envoy.get("ENVIRONMENT") {
    Error(Nil) -> Ok(Development)
    Ok(value) ->
      case string.lowercase(string.trim(value)) {
        "development" -> Ok(Development)
        "production" -> Ok(Production)
        _ -> Error(Invalid(Environment))
      }
  }
}

fn read_development_origins(
  default: List(String),
) -> Result(List(String), ConfigError) {
  case envoy.get("DEVELOPMENT_ORIGINS") {
    Error(Nil) -> Ok(default)
    Ok(value) -> {
      let value = string.trim(value)
      case value {
        "" -> Ok([])
        _ ->
          case
            list.try_map(string.split(value, on: ","), with: normalize_origin)
          {
            Ok(origins) -> Ok(origins)
            Error(Nil) -> Error(Invalid(DevelopmentOrigins))
          }
      }
    }
  }
}

fn read_public_origin() -> Result(Option(String), ConfigError) {
  case envoy.get("PUBLIC_ORIGIN") {
    Error(Nil) -> Ok(None)
    Ok(value) -> {
      let value = string.trim(value)
      case value {
        "" -> Ok(None)
        _ ->
          case normalize_origin(value) {
            Ok(origin) -> Ok(Some(origin))
            Error(Nil) -> Error(Invalid(PublicOrigin))
          }
      }
    }
  }
}

fn normalize_origin(value: String) -> Result(String, Nil) {
  let value = string.trim(value)
  case string.contains(does: value, contain: "*") {
    True -> Error(Nil)
    False ->
      case uri.parse(value) {
        Error(Nil) -> Error(Nil)
        Ok(parsed) ->
          case parsed {
            Uri(
              scheme: Some(scheme),
              userinfo: None,
              host: Some(host),
              port: port,
              path: "",
              query: None,
              fragment: None,
            ) ->
              case
                valid_origin_scheme(scheme)
                && valid_origin_host(host)
                && valid_origin_port(port)
              {
                True -> uri.origin(parsed) |> result.replace_error(Nil)
                False -> Error(Nil)
              }
            _ -> Error(Nil)
          }
      }
  }
}

pub fn valid_bind_address(value: String) -> Bool {
  value != ""
  && string.trim(value) == value
  && !contains_control_character(value)
  && {
    case value {
      "localhost" -> True
      _ ->
        case parse_address(charlist.from_string(value)) {
          Ok(_) -> True
          Error(_) -> False
        }
    }
  }
}

@external(erlang, "inet", "parse_address")
fn parse_address(value: charlist.Charlist) -> Result(Dynamic, Dynamic)

fn valid_static_directory(path: String) -> Bool {
  path != ""
  && !contains_control_character(path)
  && !contains_parent_segment(path, "/")
  && !contains_parent_segment(path, "\\")
}

fn contains_parent_segment(path: String, separator: String) -> Bool {
  path
  |> string.split(on: separator)
  |> list.any(fn(segment) { segment == ".." })
}

fn valid_origin_host(host: String) -> Bool {
  host != ""
  && !string.contains(does: host, contain: "*")
  && !contains_control_character(host)
  && !string.contains(does: host, contain: " ")
}

fn valid_origin_scheme(scheme: String) -> Bool {
  scheme == "http" || scheme == "https"
}

fn valid_origin_port(port: Option(Int)) -> Bool {
  case port {
    None -> True
    Some(value) -> value >= 1 && value <= 65_535
  }
}

fn contains_control_character(value: String) -> Bool {
  value
  |> string.to_utf_codepoints
  |> list.map(string.utf_codepoint_to_int)
  |> list.any(fn(codepoint) { codepoint <= 31 || codepoint == 127 })
}
