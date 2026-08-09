import gleam/http.{Get}
import gleam/otp/static_supervisor.{type Supervisor}
import gleam/otp/supervision.{type ChildSpecification}
import mist
import wisp
import wisp/wisp_mist

pub fn handle_request(request: wisp.Request) -> wisp.Response {
  case request.method, request.path {
    Get, "/healthz" -> wisp.ok()
    _, _ -> wisp.not_found()
  }
}

pub fn supervised(
  port: Int,
  secret_key_base: String,
) -> ChildSpecification(Supervisor) {
  handle_request
  |> wisp_mist.handler(secret_key_base)
  |> mist.new
  |> mist.port(port)
  |> mist.supervised
}
