import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/uri
import pixel_scribe_frontend/validation

const username_cookie_name = "pixel_scribe_username"

const username_cookie_max_age = "15552000"

@external(javascript, "./browser_ffi.mjs", "read_document_cookie")
fn read_document_cookie() -> String

@external(javascript, "./browser_ffi.mjs", "write_username_cookie")
fn write_username_cookie(serialized_cookie: String) -> Nil

@external(javascript, "./browser_ffi.mjs", "is_https")
fn is_https() -> Bool

@external(javascript, "./browser_ffi.mjs", "generate_page_seed")
fn generate_page_seed() -> Int

/// Reads and validates the frontend-owned username preference.
///
/// The browser boundary returns only a cookie header string. Parsing and
/// username validation remain in Gleam so malformed or missing values become
/// no preference without exposing raw cookie state to the application.
pub fn read_username_preference() -> Option(String) {
  read_document_cookie()
  |> parse_username_cookie
}

/// Writes a validated frontend-owned username preference.
///
/// Invalid input is ignored. The browser boundary receives only the complete
/// serialized named cookie; it cannot choose a cookie name or attributes.
pub fn write_username_preference(username: String) -> Nil {
  case validation.normalize_username(username) {
    Ok(normalized) ->
      write_username_cookie(serialize_username_cookie(normalized, is_https()))
    Error(_) -> Nil
  }
}

/// Generates the one per-page placement seed supplied by the browser.
///
/// The callback seam keeps callers deterministic without a production test
/// global. The browser implementation uses `crypto.getRandomValues` and
/// uses zero when that API is unavailable or throws.
pub fn page_seed() -> Int {
  page_seed_with(generate_page_seed)
}

/// Injects a deterministic seed source for pure callers and tests.
pub fn page_seed_with(source: fn() -> Int) -> Int {
  source()
}

/// Selects and validates the frontend-owned username preference from a cookie
/// header. The header is untrusted: only the first exact cookie-name match is
/// considered, and malformed or invalid values are ignored.
pub fn parse_username_cookie(cookie_header: String) -> Option(String) {
  find_username_cookie(string.split(cookie_header, on: ";"))
}

fn find_username_cookie(pairs: List(String)) -> Option(String) {
  case pairs {
    [] -> None
    [pair, ..rest] ->
      case string.split_once(pair, on: "=") {
        Error(_) -> find_username_cookie(rest)
        Ok(#(raw_name, raw_value)) -> {
          let name = trim_cookie_whitespace(raw_name)

          case name == username_cookie_name {
            True ->
              decode_username_cookie_value(trim_cookie_whitespace(raw_value))
            False -> find_username_cookie(rest)
          }
        }
      }
  }
}

fn decode_username_cookie_value(value: String) -> Option(String) {
  case uri.percent_decode(value) {
    Error(_) -> None
    Ok(decoded) ->
      case validation.normalize_username(decoded) {
        Ok(username) -> Some(username)
        Error(_) -> None
      }
  }
}

/// Serializes a validated username preference for `document.cookie`.
///
/// The username is already trusted and normalized by the frontend validation
/// boundary before this function is called. JavaScript cannot set HttpOnly, so
/// that attribute is deliberately absent.
pub fn serialize_username_cookie(username: String, secure: Bool) -> String {
  let secure_attribute = case secure {
    True -> "; Secure"
    False -> ""
  }

  username_cookie_name
  <> "="
  <> uri.percent_encode(username)
  <> "; Max-Age="
  <> username_cookie_max_age
  <> "; Path=/; SameSite=Strict"
  <> secure_attribute
}

fn trim_cookie_whitespace(value: String) -> String {
  value
  |> string.to_graphemes
  |> list.drop_while(is_cookie_whitespace)
  |> trim_cookie_whitespace_end
  |> string.concat
}

fn trim_cookie_whitespace_end(graphemes: List(String)) -> List(String) {
  graphemes
  |> list.reverse
  |> list.drop_while(is_cookie_whitespace)
  |> list.reverse
}

fn is_cookie_whitespace(grapheme: String) -> Bool {
  grapheme == " " || grapheme == "\t"
}
