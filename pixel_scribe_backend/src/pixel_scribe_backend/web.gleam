import gleam/bytes_tree
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/static_supervisor.{type Supervisor}
import gleam/otp/supervision.{type ChildSpecification}
import gleam/string
import gleam/uri
import mist
import pixel_scribe_backend/connection
import pixel_scribe_backend/room_directory
import wisp
import wisp/wisp_mist

pub fn handle_request(request: wisp.Request) -> wisp.Response {
  handle_request_from(request, "priv/public")
}

pub fn handle_request_from(
  request: wisp.Request,
  static_directory: String,
) -> wisp.Response {
  let response = case request.method, request.path {
    http.Get, "/healthz" -> wisp.ok()
    http.Get, "/" -> serve_static_path(request, "/index.html", static_directory)
    http.Get, path -> serve_static_path(request, path, static_directory)
    _, _ -> wisp.not_found()
  }

  add_security_headers(response)
}

pub fn supervised_with_options(
  port: Int,
  bind_address: String,
  secret_key_base: String,
  directory: room_directory.RoomDirectory,
  static_directory: String,
  development_origins: List(String),
) -> ChildSpecification(Supervisor) {
  mist_handler_with_options(
    directory,
    secret_key_base,
    static_directory,
    development_origins,
  )
  |> mist.new
  |> mist.bind(bind_address)
  |> mist.port(port)
  |> mist.supervised
}

pub fn supervised(
  port: Int,
  secret_key_base: String,
  directory: room_directory.RoomDirectory,
) -> ChildSpecification(Supervisor) {
  mist_handler(directory, secret_key_base)
  |> mist.new
  |> mist.bind("localhost")
  |> mist.port(port)
  |> mist.supervised
}

pub fn mist_handler(
  directory: room_directory.RoomDirectory,
  secret_key_base: String,
) -> fn(Request(mist.Connection)) -> Response(mist.ResponseData) {
  let http_handler = wisp_mist.handler(handle_request, secret_key_base)
  fn(request: Request(mist.Connection)) {
    let response = case request.method, request.path {
      http.Get, "/ws" -> connection.websocket(request, directory)
      _, _ -> http_handler(request)
    }

    add_security_headers_to_mist_response(response)
  }
}

pub fn mist_handler_with_origins(
  directory: room_directory.RoomDirectory,
  secret_key_base: String,
  allowed_origins: List(String),
) -> fn(Request(mist.Connection)) -> Response(mist.ResponseData) {
  let http_handler = wisp_mist.handler(handle_request, secret_key_base)
  fn(request: Request(mist.Connection)) {
    let response = case request.method, request.path {
      http.Get, "/ws" -> {
        case websocket_origin_allowed(request, allowed_origins) {
          True -> connection.websocket(request, directory)
          False -> forbidden_response()
        }
      }
      _, _ -> http_handler(request)
    }

    add_security_headers_to_mist_response(response)
  }
}

fn mist_handler_with_options(
  directory: room_directory.RoomDirectory,
  secret_key_base: String,
  static_directory: String,
  allowed_origins: List(String),
) -> fn(Request(mist.Connection)) -> Response(mist.ResponseData) {
  let http_handler =
    wisp_mist.handler(
      fn(request) { handle_request_from(request, static_directory) },
      secret_key_base,
    )
  fn(request: Request(mist.Connection)) {
    let response = case request.method, request.path {
      http.Get, "/ws" -> {
        case websocket_origin_allowed(request, allowed_origins) {
          True -> connection.websocket(request, directory)
          False -> forbidden_response()
        }
      }
      _, _ -> http_handler(request)
    }

    add_security_headers_to_mist_response(response)
  }
}

pub fn websocket_origin_allowed(
  request: Request(body),
  allowed_origins: List(String),
) -> Bool {
  case request.get_header(request, "origin") {
    Error(_) -> False
    Ok(origin) -> {
      case canonical_origin(origin), request_origin(request) {
        Some(origin), Some(expected) ->
          origin == expected
          || list.any(allowed_origins, fn(allowed) {
            canonical_origin(allowed) == Some(origin)
          })
        _, _ -> False
      }
    }
  }
}

fn serve_static_path(
  request: wisp.Request,
  path: String,
  static_directory: String,
) -> wisp.Response {
  case safe_static_path(path) {
    Some(path) -> {
      let request = request.set_path(request, path)
      wisp.serve_static(
        request,
        under: "/",
        from: static_directory,
        next: wisp.not_found,
      )
    }
    None -> wisp.not_found()
  }
}

fn safe_static_path(path: String) -> Option(String) {
  case uri.percent_decode(path) {
    Error(_) -> None
    Ok(decoded) -> {
      let segments = string.split(decoded, "/")
      case
        string.starts_with(decoded, "/")
        && !string.ends_with(decoded, "/")
        && !list.any(segments, unsafe_path_segment)
      {
        True -> Some(path)
        False -> None
      }
    }
  }
}

fn unsafe_path_segment(segment: String) -> Bool {
  segment == "."
  || segment == ".."
  || string.contains(segment, "\\")
  || string.contains(segment, "\u{0}")
}

fn add_security_headers(response: wisp.Response) -> wisp.Response {
  response
  |> wisp.set_header(
    "content-security-policy",
    "default-src 'self'; base-uri 'self'; object-src 'none'; "
      <> "frame-ancestors 'none'; script-src 'self'; "
      <> "style-src 'self' 'unsafe-inline'; connect-src 'self'",
  )
  |> wisp.set_header("x-content-type-options", "nosniff")
  |> wisp.set_header("x-frame-options", "DENY")
  |> wisp.set_header("referrer-policy", "no-referrer")
  |> wisp.set_header("cross-origin-opener-policy", "same-origin")
  |> wisp.set_header("cross-origin-resource-policy", "same-origin")
}

fn add_security_headers_to_mist_response(
  response: Response(mist.ResponseData),
) -> Response(mist.ResponseData) {
  response
  |> response.set_header(
    "content-security-policy",
    "default-src 'self'; base-uri 'self'; object-src 'none'; "
      <> "frame-ancestors 'none'; script-src 'self'; "
      <> "style-src 'self' 'unsafe-inline'; connect-src 'self'",
  )
  |> response.set_header("x-content-type-options", "nosniff")
  |> response.set_header("x-frame-options", "DENY")
  |> response.set_header("referrer-policy", "no-referrer")
  |> response.set_header("cross-origin-opener-policy", "same-origin")
  |> response.set_header("cross-origin-resource-policy", "same-origin")
}

fn forbidden_response() -> Response(mist.ResponseData) {
  response.new(403)
  |> response.set_body(mist.Bytes(bytes_tree.from_string("Forbidden")))
}

fn request_origin(request: Request(body)) -> Option(String) {
  uri.origin(uri.Uri(
    scheme: Some(http.scheme_to_string(request.scheme)),
    userinfo: None,
    host: Some(request.host),
    port: request.port,
    path: "",
    query: None,
    fragment: None,
  ))
  |> option_from_result
}

fn canonical_origin(origin: String) -> Option(String) {
  case uri.parse(string.trim(origin)) {
    Ok(parsed) ->
      case parsed {
        uri.Uri(userinfo: None, path: "", query: None, fragment: None, ..) ->
          uri.origin(parsed) |> option_from_result
        _ -> None
      }
    _ -> None
  }
}

fn option_from_result(result: Result(String, Nil)) -> Option(String) {
  case result {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}
