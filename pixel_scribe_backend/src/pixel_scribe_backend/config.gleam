import envoy
import gleam/int
import gleam/result

pub type Config {
  Config(port: Int)
}

pub fn load() -> Result(Config, Nil) {
  let str_port = envoy.get("PORT") |> result.unwrap("8080")
  use port <- result.try(int.parse(str_port))

  Ok(Config(port))
}
