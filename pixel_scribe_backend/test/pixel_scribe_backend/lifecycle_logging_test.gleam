import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import pixel_scribe_backend/domain
import pixel_scribe_backend/lifecycle_logging

const lifecycle_keys = ["connection_id", "event", "room_id", "user_count"]

const reason_lifecycle_keys = [
  "connection_id",
  "event",
  "reason",
  "room_id",
  "user_count",
]

pub fn lifecycle_reports_have_allowlisted_typed_fields_test() {
  let accepted_id = domain.new_connection_id()
  assert_report(
    lifecycle_logging.report(lifecycle_logging.RoomJoined(
      domain.default_room_id,
      accepted_id,
      2,
    )),
    lifecycle_keys,
    "room_joined",
    "default",
    domain.connection_id_to_string(accepted_id),
    None,
    2,
  )

  assert_report(
    lifecycle_logging.report(lifecycle_logging.RoomJoinRejected(
      domain.default_room_id,
      lifecycle_logging.RoomFull,
      50,
    )),
    reason_lifecycle_keys,
    "room_join_rejected",
    "default",
    "none",
    Some("room_full"),
    50,
  )

  let left_id = domain.new_connection_id()
  assert_report(
    lifecycle_logging.report(lifecycle_logging.RoomLeft(
      domain.default_room_id,
      left_id,
      1,
    )),
    lifecycle_keys,
    "room_left",
    "default",
    domain.connection_id_to_string(left_id),
    None,
    1,
  )

  assert_report(
    lifecycle_logging.report(lifecycle_logging.RoomUnexpectedFailure(
      Some(domain.default_room_id),
      None,
      Some(3),
      lifecycle_logging.JoinSinkUnavailable,
    )),
    reason_lifecycle_keys,
    "room_unexpected_failure",
    "default",
    "none",
    Some("join_sink_unavailable"),
    3,
  )
}

fn assert_report(
  report: Dict(String, Dynamic),
  expected_keys: List(String),
  event: String,
  room_id: String,
  connection_id: String,
  reason: Option(String),
  user_count: Int,
) -> Nil {
  assert list.sort(dict.keys(report), by: string.compare)
    == list.sort(expected_keys, by: string.compare)
  assert string_field(report, "event") == event
  assert string_field(report, "room_id") == room_id
  assert string_field(report, "connection_id") == connection_id
  case reason {
    None -> Nil
    Some(reason) -> {
      assert string_field(report, "reason") == reason
      Nil
    }
  }
  assert int_field(report, "user_count") == user_count
}

fn string_field(report: Dict(String, Dynamic), key: String) -> String {
  let assert Ok(value) = dict.get(report, key)
  let assert Ok(value) = decode.run(value, decode.string)
  value
}

fn int_field(report: Dict(String, Dynamic), key: String) -> Int {
  let assert Ok(value) = dict.get(report, key)
  let assert Ok(value) = decode.run(value, decode.int)
  value
}
