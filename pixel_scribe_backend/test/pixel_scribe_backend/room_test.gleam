import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/string
import gleam/time/timestamp
import pixel_scribe_backend/domain
import pixel_scribe_backend/room

pub fn join_returns_snapshot_and_notifies_existing_connections_test() {
  let assert Ok(room_actor) = room.start(domain.default_room_id)
  let #(first_connection, first_subject) = new_connection()
  let #(second_connection, second_subject) = new_connection()
  let ada = username("Ada")
  let grace = username("Grace")

  room.join(room_actor, ada, first_connection)
  let assert room.Joined(room_id, first_id, first_users, first_messages) =
    receive_event(first_subject)

  assert domain.room_id_to_string(room_id) == "default"
  assert list.length(first_users) == 1
  let assert Ok(first_user) = list.first(first_users)
  assert domain.presence_connection_id(first_user) == first_id
  assert domain.presence_username(first_user) == ada
  assert first_messages == []

  room.join(room_actor, grace, second_connection)
  let assert room.UserJoined(_, joined_user) = receive_event(first_subject)
  let assert room.Joined(_, second_id, second_users, second_messages) =
    receive_event(second_subject)

  assert second_id != first_id
  assert domain.presence_connection_id(joined_user) == second_id
  assert domain.presence_username(joined_user) == grace
  assert list.length(second_users) == 2
  assert second_messages == []
}

pub fn duplicate_usernames_have_distinct_connection_ids_test() {
  let assert Ok(room_actor) = room.start(domain.default_room_id)
  let #(first_connection, first_subject) = new_connection()
  let #(second_connection, second_subject) = new_connection()
  let username = username("Ada")

  room.join(room_actor, username, first_connection)
  let assert room.Joined(_, first_id, _, _) = receive_event(first_subject)

  room.join(room_actor, username, second_connection)
  let assert room.UserJoined(_, joined_user) = receive_event(first_subject)
  let assert room.Joined(_, second_id, users, _) = receive_event(second_subject)

  assert first_id != second_id
  assert domain.presence_username(joined_user) == username
  assert list.length(users) == 2
}

pub fn fifty_first_join_is_rejected_without_mutating_capacity_test() {
  let assert Ok(room_actor) = room.start(domain.default_room_id)
  let connections =
    int.range(from: 1, to: 51, with: [], run: fn(connections, _) {
      [new_connection(), ..connections]
    })

  list.each(connections, fn(item) {
    let #(connection, _) = item
    room.join(room_actor, username("Ada"), connection)
  })

  list.each(connections, fn(item) {
    let #(_, subject) = item
    let assert room.Joined(_, _, users, _) = receive_event(subject)
    assert list.length(users) >= 1
  })

  let #(rejected_connection, rejected_subject) = new_connection()
  room.join(room_actor, username("Ada"), rejected_connection)

  let assert room.JoinRejected(room_id, room.RoomFull) =
    receive_event(rejected_subject)
  assert domain.room_id_to_string(room_id) == "default"
}

pub fn explicit_leave_is_idempotent_and_broadcasts_once_test() {
  let assert Ok(room_actor) = room.start(domain.default_room_id)
  let #(first_connection, first_subject) = new_connection()
  let #(second_connection, second_subject) = new_connection()

  room.join(room_actor, username("Ada"), first_connection)
  let assert room.Joined(_, first_id, _, _) = receive_event(first_subject)
  room.join(room_actor, username("Grace"), second_connection)
  let assert room.UserJoined(_, _) = receive_event(first_subject)
  let assert room.Joined(_, _, _, _) = receive_event(second_subject)

  room.leave(room_actor, first_id)
  let assert room.UserLeft(_, left_id) = receive_event(second_subject)
  assert left_id == first_id

  room.leave(room_actor, first_id)
  assert process.receive(from: second_subject, within: 50) == Error(Nil)
}

pub fn messages_are_ordered_and_history_evicts_oldest_test() {
  let assert Ok(room_actor) = room.start(domain.default_room_id)
  let #(connection, subject) = new_connection()

  room.join(room_actor, username("Ada"), connection)
  let assert room.Joined(_, connection_id, _, _) = receive_event(subject)
  send_messages(room_actor, connection_id, 1, 51)

  let messages = receive_messages(subject, 51, [])
  let assert Ok(first_message) = list.first(messages)
  let assert Ok(last_message) = list.last(messages)
  assert domain.message_id_to_string(domain.chat_message_message_id(
      first_message,
    ))
    |> string.starts_with("message-")
  let first_sent_at = domain.chat_message_sent_at(first_message)
  let assert Ok(_) =
    first_sent_at
    |> domain.sent_at_to_rfc3339
    |> timestamp.parse_rfc3339
  assert domain.message_text_to_string(domain.chat_message_text(first_message))
    == "message-1"
  assert domain.message_text_to_string(domain.chat_message_text(last_message))
    == "message-51"

  let #(second_connection, second_subject) = new_connection()
  room.join(room_actor, username("Grace"), second_connection)
  let assert room.UserJoined(_, _) = receive_event(subject)
  let assert room.Joined(_, _, _, history) = receive_event(second_subject)

  assert list.length(history) == 50
  let assert Ok(first_history_message) = list.first(history)
  let assert Ok(last_history_message) = list.last(history)
  assert domain.message_text_to_string(domain.chat_message_text(
      first_history_message,
    ))
    == "message-2"
  assert domain.message_text_to_string(domain.chat_message_text(
      last_history_message,
    ))
    == "message-51"
}

pub fn unknown_senders_do_not_mutate_history_or_broadcast_test() {
  let assert Ok(room_actor) = room.start(domain.default_room_id)
  let #(connection, subject) = new_connection()
  let assert Ok(text) = domain.new_message_text("ignored")

  room.join(room_actor, username("Ada"), connection)
  let assert room.Joined(_, _, _, _) = receive_event(subject)
  room.send_message(room_actor, domain.new_connection_id(), text)
  assert process.receive(from: subject, within: 50) == Error(Nil)

  let #(second_connection, second_subject) = new_connection()
  room.join(room_actor, username("Grace"), second_connection)
  let assert room.UserJoined(_, _) = receive_event(subject)
  let assert room.Joined(_, _, _, history) = receive_event(second_subject)
  assert history == []
}

pub fn process_down_cleanup_is_idempotent_test() {
  let assert Ok(room_actor) = room.start(domain.default_room_id)
  let #(remote_pid, remote_connection, remote_subject) = new_remote_connection()
  let #(remaining_connection, remaining_subject) = new_connection()

  room.join(room_actor, username("Ada"), remote_connection)
  let assert room.Joined(_, _, _, _) = receive_event(remote_subject)
  room.join(room_actor, username("Grace"), remaining_connection)
  let assert room.UserJoined(_, _) = receive_event(remote_subject)
  let assert room.Joined(_, _, _, _) = receive_event(remaining_subject)

  process.kill(remote_pid)
  let assert room.UserLeft(_, _) = receive_event(remaining_subject)
  room.connection_down(room_actor, remote_pid)
  assert process.receive(from: remaining_subject, within: 50) == Error(Nil)
}

pub fn dead_connections_do_not_consume_presence_capacity_test() {
  let assert Ok(room_actor) = room.start(domain.default_room_id)
  let #(dead_pid, dead_connection, _) = new_remote_connection()
  let #(live_connection, live_subject) = new_connection()

  process.kill(dead_pid)
  room.join(room_actor, username("Dead"), dead_connection)
  room.join(room_actor, username("Ada"), live_connection)

  let assert room.Joined(_, _, users, _) = receive_event(live_subject)
  assert list.length(users) == 1
}

fn new_connection() -> #(room.ConnectionSink, process.Subject(room.RoomEvent)) {
  let subject = process.new_subject()
  #(room.new_connection_sink(subject, process.self()), subject)
}

fn receive_event(subject: process.Subject(room.RoomEvent)) -> room.RoomEvent {
  let assert Ok(event) = process.receive(from: subject, within: 1000)
  event
}

fn send_messages(
  room_actor: room.Room,
  connection_id: domain.ConnectionId,
  next: Int,
  last: Int,
) -> Nil {
  case next > last {
    True -> Nil
    False -> {
      let assert Ok(text) =
        domain.new_message_text("message-" <> int.to_string(next))
      room.send_message(room_actor, connection_id, text)
      send_messages(room_actor, connection_id, next + 1, last)
    }
  }
}

fn receive_messages(
  subject: process.Subject(room.RoomEvent),
  remaining: Int,
  messages: List(domain.ChatMessage),
) -> List(domain.ChatMessage) {
  case remaining {
    0 -> list.reverse(messages)
    _ -> {
      let assert room.MessageSent(_, message) = receive_event(subject)
      receive_messages(subject, remaining - 1, [message, ..messages])
    }
  }
}

fn new_remote_connection() -> #(
  process.Pid,
  room.ConnectionSink,
  process.Subject(room.RoomEvent),
) {
  let ready = process.new_subject()
  let forwarded_events = process.new_subject()
  let _ =
    process.spawn_unlinked(fn() {
      let subject: process.Subject(room.RoomEvent) = process.new_subject()
      process.send(ready, #(process.self(), subject))
      forward_events(subject, forwarded_events)
    })
  let assert Ok(#(pid, subject)) = process.receive(from: ready, within: 1000)
  #(pid, room.new_connection_sink(subject, pid), forwarded_events)
}

fn forward_events(
  from subject: process.Subject(room.RoomEvent),
  to target: process.Subject(room.RoomEvent),
) -> Nil {
  let event = process.receive_forever(from: subject)
  process.send(target, event)
  forward_events(from: subject, to: target)
}

fn username(raw: String) -> domain.Username {
  let assert Ok(value) = domain.new_username(raw)
  value
}
