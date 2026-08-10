import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/uri
import pixel_scribe_frontend/validation

const username_cookie_name = "pixel_scribe_username"

const username_cookie_max_age = "15552000"

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
