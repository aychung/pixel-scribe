import envoy
import gleam/int
import gleam/result

pub type Config {
  Config(bind_address: String, port: Int)
}

pub fn load() -> Result(Config, Nil) {
  let bind_address = envoy.get("HOST") |> result.unwrap("localhost")
  let str_port = envoy.get("PORT") |> result.unwrap("8080")
  use port <- result.try(int.parse(str_port))

  Ok(Config(bind_address, port))
}
