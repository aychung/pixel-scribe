import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option, None, Some}
import logging
import pixel_scribe_backend/domain

pub type Event {
  RoomJoined(domain.RoomId, domain.ConnectionId, Int)
  RoomJoinRejected(domain.RoomId, Reason, Int)
  RoomLeft(domain.RoomId, domain.ConnectionId, Int)
  RoomUnexpectedFailure(
    Option(domain.RoomId),
    Option(domain.ConnectionId),
    Option(Int),
    Reason,
  )
}

pub type Reason {
  RoomFull
  JoinSinkUnavailable
  RoomUnavailable
  RoomStartFailed
  RoomRegistrationFailed
}

type DoNotLeak

@internal
pub fn report(event: Event) -> Dict(String, Dynamic) {
  let #(event_name, room_id, connection_id, user_count, reason) = case event {
    RoomJoined(room_id, connection_id, user_count) -> #(
      "room_joined",
      Some(room_id),
      Some(connection_id),
      Some(user_count),
      None,
    )
    RoomJoinRejected(room_id, reason, user_count) -> #(
      "room_join_rejected",
      Some(room_id),
      None,
      Some(user_count),
      Some(reason_to_string(reason)),
    )
    RoomLeft(room_id, connection_id, user_count) -> #(
      "room_left",
      Some(room_id),
      Some(connection_id),
      Some(user_count),
      None,
    )
    RoomUnexpectedFailure(room_id, connection_id, user_count, reason) -> #(
      "room_unexpected_failure",
      room_id,
      connection_id,
      user_count,
      Some(reason_to_string(reason)),
    )
  }
  fields(event_name, room_id, connection_id, user_count, reason)
}

/// Emit one lifecycle event at the level appropriate to its meaning.
pub fn log(event: Event) -> Nil {
  let level = case event {
    RoomJoinRejected(_, _, _) -> logging.Warning
    RoomUnexpectedFailure(_, _, _, _) -> logging.Error
    RoomJoined(_, _, _) | RoomLeft(_, _, _) -> logging.Info
  }
  let _ = erlang_log(level, report(event))
  Nil
}

@external(erlang, "logger", "log")
fn erlang_log(
  level: logging.LogLevel,
  report: Dict(String, Dynamic),
) -> DoNotLeak

fn fields(
  event: String,
  room_id: Option(domain.RoomId),
  connection_id: Option(domain.ConnectionId),
  user_count: Option(Int),
  reason: Option(String),
) -> Dict(String, Dynamic) {
  let fields =
    dict.from_list([
      #("event", dynamic.string(event)),
      #("room_id", dynamic.string(optional_room_id_to_string(room_id))),
      #(
        "connection_id",
        dynamic.string(optional_connection_id_to_string(connection_id)),
      ),
    ])
  let fields = case user_count {
    None -> fields
    Some(count) -> dict.insert(fields, "user_count", dynamic.int(count))
  }
  case reason {
    None -> fields
    Some(reason) -> dict.insert(fields, "reason", dynamic.string(reason))
  }
}

fn reason_to_string(reason: Reason) -> String {
  case reason {
    RoomFull -> "room_full"
    JoinSinkUnavailable -> "join_sink_unavailable"
    RoomUnavailable -> "room_unavailable"
    RoomStartFailed -> "room_start_failed"
    RoomRegistrationFailed -> "room_registration_failed"
  }
}

fn optional_room_id_to_string(room_id: Option(domain.RoomId)) -> String {
  case room_id {
    None -> "none"
    Some(room_id) -> domain.room_id_to_string(room_id)
  }
}

fn optional_connection_id_to_string(
  connection_id: Option(domain.ConnectionId),
) -> String {
  case connection_id {
    None -> "none"
    Some(connection_id) -> domain.connection_id_to_string(connection_id)
  }
}
