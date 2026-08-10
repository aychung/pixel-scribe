import gleam/http.{Get}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/otp/static_supervisor.{type Supervisor}
import gleam/otp/supervision.{type ChildSpecification}
import mist
import pixel_scribe_backend/connection
import pixel_scribe_backend/room_directory
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
  directory: room_directory.RoomDirectory,
) -> ChildSpecification(Supervisor) {
  mist_handler(directory, secret_key_base)
  |> mist.new
  |> mist.port(port)
  |> mist.supervised
}

pub fn mist_handler(
  directory: room_directory.RoomDirectory,
  secret_key_base: String,
) -> fn(Request(mist.Connection)) -> Response(mist.ResponseData) {
  let http_handler = wisp_mist.handler(handle_request, secret_key_base)
  fn(request: Request(mist.Connection)) {
    case request.method, request.path {
      Get, "/ws" -> connection.websocket(request, directory)
      _, _ -> http_handler(request)
    }
  }
}
