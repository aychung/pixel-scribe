import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/uri
import lustre/effect.{type Effect}
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

@external(javascript, "./browser_ffi.mjs", "schedule_timer")
fn schedule_timer_ffi(
  timer_kind: Int,
  generation: Int,
  timer_id: Int,
  delay_ms: Int,
  callback: fn(Int, Int) -> Nil,
) -> Nil

@external(javascript, "./browser_ffi.mjs", "cancel_timer")
fn cancel_timer_ffi(timer_kind: Int, generation: Int, timer_id: Int) -> Nil

@external(javascript, "./browser_ffi.mjs", "focus_username")
fn focus_username_ffi() -> Nil

@external(javascript, "./browser_ffi.mjs", "focus_composer")
fn focus_composer_ffi() -> Nil

@external(javascript, "./browser_ffi.mjs", "scroll_chat_to_end")
fn scroll_chat_to_end_ffi() -> Nil

/// Namespaces for timers owned by separate application concerns. A timer ID
/// is opaque within its namespace, so reconnect cleanup cannot cancel a
/// rate-limit timer that happens to use the same integer.
pub type TimerKind {
  Reconnect
  RateLimit
  Bubble
}

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

/// Schedules a browser timer that sends its typed identity back through the
/// supplied Lustre message constructor. The generation is deliberately part
/// of the callback, so the state machine can ignore a callback from a stale
/// socket lifetime even when a cancellation races with the browser timer.
pub fn schedule_timer(
  kind: TimerKind,
  generation: Int,
  timer_id: Int,
  delay_ms: Int,
  message: fn(Int, Int) -> a,
) -> Effect(a) {
  effect.from(fn(dispatch) {
    schedule_timer_ffi(
      timer_kind_code(kind),
      generation,
      timer_id,
      delay_ms,
      fn(fired_generation, fired_timer_id) {
        dispatch(message(fired_generation, fired_timer_id))
      },
    )
  })
}

/// Cancels one timer by its namespace, generation, and identity. Cancellation
/// is idempotent, so cleanup paths can safely run after a timer has fired or
/// after an older generation has already been replaced.
pub fn cancel_timer(
  kind: TimerKind,
  generation: Int,
  timer_id: Int,
) -> Effect(a) {
  effect.from(fn(_dispatch) {
    cancel_timer_ffi(timer_kind_code(kind), generation, timer_id)
  })
}

/// Focuses the application-owned username input after Lustre has applied its
/// latest view. The target is fixed in the browser boundary and a missing node
/// is a harmless no-op.
pub fn focus_username() -> Effect(a) {
  effect.before_paint(fn(_dispatch, _root) { focus_username_ffi() })
}

/// Focuses the application-owned chat composer after Lustre has applied its
/// latest view. The target is fixed in the browser boundary and a missing node
/// is a harmless no-op.
pub fn focus_composer() -> Effect(a) {
  effect.before_paint(fn(_dispatch, _root) { focus_composer_ffi() })
}

/// Scrolls the application-owned chat log to its end after Lustre has applied
/// its latest view. A missing node is a harmless no-op.
pub fn scroll_chat_to_end() -> Effect(a) {
  effect.before_paint(fn(_dispatch, _root) { scroll_chat_to_end_ffi() })
}

fn timer_kind_code(kind: TimerKind) -> Int {
  case kind {
    Reconnect -> 0
    RateLimit -> 1
    Bubble -> 2
  }
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
