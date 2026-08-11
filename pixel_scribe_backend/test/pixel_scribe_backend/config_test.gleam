import envoy
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import pixel_scribe_backend/config

pub fn loads_explicit_development_configuration_test() {
  let result =
    with_clean_environment(fn() {
      envoy.set("PORT", "4310")
      envoy.set("HOST", "127.0.0.1")
      envoy.set("SECRET_KEY_BASE", string.repeat("development-secret-", 5))
      envoy.set("STATIC_DIRECTORY", "priv/test-public")
      envoy.set("ENVIRONMENT", "development")
      envoy.set(
        "DEVELOPMENT_ORIGINS",
        "http://localhost:1234, https://frontend.example.test",
      )
      envoy.set("PUBLIC_ORIGIN", "https://example.test")

      config.load()
    })

  let assert Ok(value) = result
  assert config.port(value) == 4310
  assert config.bind_address(value) == "127.0.0.1"
  assert config.secret_key_base(value)
    == string.repeat("development-secret-", 5)
  assert config.static_directory(value) == "priv/test-public"
  assert config.environment(value) == config.Development
  assert config.development_origins(value)
    == ["http://localhost:1234", "https://frontend.example.test"]
  assert config.public_origin(value) == Some("https://example.test")
}

pub fn uses_safe_defaults_but_requires_the_secret_test() {
  let missing_secret = with_clean_environment(fn() { config.load() })
  assert missing_secret == Error(config.Missing(config.SecretKeyBase))

  let result =
    with_clean_environment(fn() {
      envoy.set("SECRET_KEY_BASE", string.repeat("safe-development-key-", 4))
      config.load()
    })

  let assert Ok(value) = result
  assert config.port(value) == 4000
  assert config.bind_address(value) == "localhost"
  assert config.static_directory(value) == "priv/public"
  assert config.environment(value) == config.Development
  assert config.development_origins(value) == ["http://localhost:1234"]
  assert config.public_origin(value) == None
}

pub fn accepts_production_without_development_origins_test() {
  let result =
    with_clean_environment(fn() {
      envoy.set("SECRET_KEY_BASE", string.repeat("production-secret-", 4))
      envoy.set("ENVIRONMENT", "production")
      config.load()
    })

  let assert Ok(value) = result
  assert config.environment(value) == config.Production
  assert config.development_origins(value) == []
  assert config.public_origin(value) == None
}

pub fn rejects_invalid_public_origins_test() {
  let wildcard =
    with_clean_environment(fn() {
      envoy.set("SECRET_KEY_BASE", string.repeat("secret-", 12))
      envoy.set("PUBLIC_ORIGIN", "https://*.example.test")
      config.load()
    })
  assert wildcard == Error(config.Invalid(config.PublicOrigin))

  let path =
    with_clean_environment(fn() {
      envoy.set("SECRET_KEY_BASE", string.repeat("secret-", 12))
      envoy.set("PUBLIC_ORIGIN", "https://example.test/chat")
      config.load()
    })
  assert path == Error(config.Invalid(config.PublicOrigin))
}

pub fn rejects_invalid_port_test() {
  let result =
    with_clean_environment(fn() {
      envoy.set("PORT", "0")
      envoy.set("SECRET_KEY_BASE", string.repeat("secret-", 12))
      config.load()
    })

  assert result == Error(config.Invalid(config.Port))
}

pub fn accepts_ipv4_and_ipv6_bind_addresses_test() {
  let ipv4 =
    with_clean_environment(fn() {
      envoy.set("HOST", "192.168.1.42")
      envoy.set("SECRET_KEY_BASE", string.repeat("secret-", 12))
      config.load()
    })
  let assert Ok(ipv4) = ipv4
  assert config.bind_address(ipv4) == "192.168.1.42"

  let ipv6 =
    with_clean_environment(fn() {
      envoy.set("HOST", "::")
      envoy.set("SECRET_KEY_BASE", string.repeat("secret-", 12))
      config.load()
    })
  let assert Ok(ipv6) = ipv6
  assert config.bind_address(ipv6) == "::"
}

pub fn rejects_invalid_bind_addresses_test() {
  let result =
    with_clean_environment(fn() {
      envoy.set("HOST", "0.0.0.0; touch /tmp/pwned")
      envoy.set("SECRET_KEY_BASE", string.repeat("secret-", 12))
      config.load()
    })

  assert result == Error(config.Invalid(config.BindAddress))
}

pub fn rejects_invalid_secret_test() {
  let result =
    with_clean_environment(fn() {
      envoy.set("SECRET_KEY_BASE", "too-short")
      config.load()
    })

  assert result == Error(config.Invalid(config.SecretKeyBase))
}

pub fn rejects_invalid_mode_test() {
  let result =
    with_clean_environment(fn() {
      envoy.set("SECRET_KEY_BASE", string.repeat("secret-", 12))
      envoy.set("ENVIRONMENT", "staging")
      config.load()
    })

  assert result == Error(config.Invalid(config.Environment))
}

pub fn rejects_wildcard_origins_and_traversal_test() {
  let wildcard =
    with_clean_environment(fn() {
      envoy.set("SECRET_KEY_BASE", string.repeat("secret-", 12))
      envoy.set("DEVELOPMENT_ORIGINS", "*")
      config.load()
    })
  assert wildcard == Error(config.Invalid(config.DevelopmentOrigins))

  let traversal =
    with_clean_environment(fn() {
      envoy.set("SECRET_KEY_BASE", string.repeat("secret-", 12))
      envoy.set("STATIC_DIRECTORY", "../public")
      config.load()
    })
  assert traversal == Error(config.Invalid(config.StaticDirectory))
}

type PreviousValue {
  WasMissing
  WasSet(String)
}

fn with_clean_environment(run: fn() -> a) -> a {
  let names = [
    "PORT",
    "HOST",
    "SECRET_KEY_BASE",
    "STATIC_DIRECTORY",
    "ENVIRONMENT",
    "DEVELOPMENT_ORIGINS",
    "PUBLIC_ORIGIN",
  ]
  let previous = list.map(names, fn(name) { #(name, previous_value(name)) })
  list.each(names, envoy.unset)
  let result = run()
  list.each(previous, fn(entry) { restore(entry.0, entry.1) })
  result
}

fn previous_value(name: String) -> PreviousValue {
  case envoy.get(name) {
    Ok(value) -> WasSet(value)
    Error(Nil) -> WasMissing
  }
}

fn restore(name: String, value: PreviousValue) -> Nil {
  case value {
    WasMissing -> envoy.unset(name)
    WasSet(value) -> envoy.set(name, value)
  }
}
