import gleam/http.{Get}
import gleam/http/response.{Response}
import gleam/list
import pixel_scribe_backend/web
import wisp
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

pub fn root_serves_the_known_entry_file_with_security_headers_test() {
  let response = web.handle_request(simulate.request(Get, "/"))
  let Response(status, headers, body) = response

  assert status == 200
  assert response_header(headers, "content-security-policy") != Error(Nil)
  assert response_header(headers, "x-content-type-options") == Ok("nosniff")
  assert response_header(headers, "x-frame-options") == Ok("DENY")
  assert case body {
    wisp.File(path: "priv/public/index.html", ..) -> True
    _ -> False
  }
}

pub fn traversal_and_missing_assets_are_not_found_test() {
  let traversal = web.handle_request(simulate.request(Get, "/../gleam.toml"))
  let encoded = web.handle_request(simulate.request(Get, "/%2e%2e/gleam.toml"))
  let missing = web.handle_request(simulate.request(Get, "/missing.js"))

  assert traversal.status == 404
  assert encoded.status == 404
  assert missing.status == 404
}

pub fn websocket_origins_must_be_explicit_or_same_origin_test() {
  let request = simulate.request(Get, "/ws")
  assert !web.websocket_origin_allowed(request, [])
  assert web.websocket_origin_allowed(
    simulate.header(request, "origin", "https://wisp.example.com"),
    [],
  )
  assert web.websocket_origin_allowed(
    simulate.header(request, "origin", "http://localhost:1234"),
    ["http://localhost:1234"],
  )
  assert !web.websocket_origin_allowed(
    simulate.header(request, "origin", "https://evil.example"),
    ["http://localhost:1234"],
  )
}

fn response_header(
  headers: List(#(String, String)),
  name: String,
) -> Result(String, Nil) {
  list.key_find(headers, name)
}
