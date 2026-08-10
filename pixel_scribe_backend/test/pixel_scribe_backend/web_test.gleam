import gleam/http.{Get}
import gleam/http/response.{Response}
import pixel_scribe_backend/web
import wisp/simulate

pub fn healthz_returns_success_test() {
  let Response(status, _, _) =
    web.handle_request(simulate.request(Get, "/healthz"))

  assert status == 200
}

pub fn unknown_paths_return_not_found_test() {
  let Response(status, _, _) =
    web.handle_request(simulate.request(Get, "/missing"))

  assert status == 404
}
