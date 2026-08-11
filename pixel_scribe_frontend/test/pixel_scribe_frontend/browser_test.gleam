import gleam/list
import gleam/option.{None, Some}
import gleam/string
import pixel_scribe_frontend/browser

pub fn only_the_exact_username_cookie_name_is_selected_test() {
  assert browser.parse_username_cookie(
      "other=Ada; pixel_scribe_username=Grace; pixel_scribe_username_extra=Eve",
    )
    == Some("Grace")

  assert browser.parse_username_cookie(
      "pixel_scribe_username_extra=Ada; pixel_scribe_usernameish=Grace",
    )
    == None
}

pub fn cookie_pairs_allow_optional_ascii_space_and_tab_test() {
  assert browser.parse_username_cookie(
      "other=Ada;\tpixel_scribe_username\t=\tGrace\t; next=value",
    )
    == Some("Grace")
}

pub fn cookie_values_split_on_the_first_equals_test() {
  assert browser.parse_username_cookie("pixel_scribe_username=Ada=Ace")
    == Some("Ada=Ace")
}

pub fn malformed_missing_empty_and_invalid_preferences_are_ignored_test() {
  let invalid_headers = [
    "",
    "other=Ada",
    "pixel_scribe_username",
    "pixel_scribe_username=",
    "pixel_scribe_username=%E0%A4%A",
    "pixel_scribe_username=%FF",
    "pixel_scribe_username=Ada%0A",
    "pixel_scribe_username=%20%20",
  ]

  assert list.all(invalid_headers, fn(header) {
    browser.parse_username_cookie(header) == None
  })
}

pub fn malformed_first_duplicate_does_not_fall_through_to_another_value_test() {
  assert browser.parse_username_cookie(
      "pixel_scribe_username=%FF; pixel_scribe_username=Grace",
    )
    == None
}

pub fn valid_unicode_username_round_trips_through_percent_encoding_test() {
  let username = "Zoë 🧑🏽‍💻 + = ; %"
  let serialized = browser.serialize_username_cookie(username, False)

  assert serialized
    == "pixel_scribe_username=Zo%C3%AB%20%F0%9F%A7%91%F0%9F%8F%BD%E2%80%8D%F0%9F%92%BB%20+%20%3D%20%3B%20%25; Max-Age=15552000; Path=/; SameSite=Strict"
  assert browser.parse_username_cookie(serialized) == Some(username)
}

pub fn username_cookie_attributes_are_exact_for_http_and_https_test() {
  assert browser.serialize_username_cookie("Ada", False)
    == "pixel_scribe_username=Ada; Max-Age=15552000; Path=/; SameSite=Strict"
  assert browser.serialize_username_cookie("Ada", True)
    == "pixel_scribe_username=Ada; Max-Age=15552000; Path=/; SameSite=Strict; Secure"

  let https_cookie = browser.serialize_username_cookie("Ada", True)
  assert !string.contains(https_cookie, "Domain")
  assert !string.contains(https_cookie, "HttpOnly")
}

pub fn valid_timestamp_is_formatted_for_local_display_test() {
  let timestamp = "2026-08-10T16:00:00Z"
  let formatted = browser.format_timestamp_local(timestamp)

  assert string.length(formatted) > 0
  assert formatted != timestamp
}

pub fn invalid_timestamp_falls_back_to_the_original_input_test() {
  let invalid = "not-a-timestamp"

  assert browser.format_timestamp_local(invalid) == invalid
}

pub fn chat_log_near_bottom_is_false_without_the_fixed_dom_target_test() {
  assert browser.chat_log_near_bottom() == False
}
