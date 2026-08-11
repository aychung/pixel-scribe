import exception
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/time/timestamp
import gramps/websocket
import pixel_scribe_backend/domain
import pixel_scribe_backend/integration_support as support
import pixel_scribe_backend/room
import pixel_scribe_backend/room_directory

pub fn two_clients_join_and_disconnect_over_websocket_test() {
  let server =
    support.start_server("test/fixtures/public", None, ["http://127.0.0.1"])

  exception.defer(fn() { support.stop_server(server) }, fn() {
    let first =
      support.connect_websocket(
        support.server_port(server),
        "127.0.0.1",
        "http://127.0.0.1",
      )

    exception.defer(fn() { support.close_client(first) }, fn() {
      support.send_join(first, "Ada")
      let assert Ok(#(first_state, first)) = support.read_frame(first, 1000)
      let assert Ok(first_state) = support.decode_room_state(first_state)
      assert first_state.room_id == "default"
      assert list.length(first_state.users) == 1
      assert first_state.users
        == [support.WirePresence(first_state.self_id, "Ada")]

      let second =
        support.connect_websocket(
          support.server_port(server),
          "127.0.0.1",
          "http://127.0.0.1",
        )
      exception.defer(fn() { support.close_client(second) }, fn() {
        support.send_join(second, "Ada")
        let assert Ok(#(second_state, second)) =
          support.read_frame(second, 1000)
        let assert Ok(second_state) = support.decode_room_state(second_state)
        assert second_state.room_id == "default"
        assert second_state.self_id != first_state.self_id
        assert list.length(second_state.users) == 2
        assert list.all(second_state.users, fn(user) { user.username == "Ada" })
        assert list.any(second_state.users, fn(user) {
          user.connection_id == first_state.self_id
        })
        assert list.any(second_state.users, fn(user) {
          user.connection_id == second_state.self_id
        })

        let assert Ok(#(joined_event, first)) = support.read_frame(first, 1000)
        let assert Ok(joined) = support.decode_user_joined(joined_event)
        assert joined.room_id == "default"
        assert joined.user == support.WirePresence(second_state.self_id, "Ada")
        assert support.read_frame(first, 50) == Error(Nil)

        support.close_client(second)
        let assert Ok(#(left_event, first)) = support.read_frame(first, 1000)
        let assert Ok(left) = support.decode_user_left(left_event)
        assert left.room_id == "default"
        assert left.connection_id == second_state.self_id
        assert support.read_frame(first, 50) == Error(Nil)
      })
    })
  })
}

pub fn accepted_messages_are_broadcast_with_server_metadata_test() {
  let server =
    support.start_server("test/fixtures/public", None, ["http://127.0.0.1"])

  exception.defer(fn() { support.stop_server(server) }, fn() {
    let first =
      support.connect_websocket(
        support.server_port(server),
        "127.0.0.1",
        "http://127.0.0.1",
      )
    exception.defer(fn() { support.close_client(first) }, fn() {
      support.send_join(first, "Ada")
      let assert Ok(#(first_state, first)) = support.read_frame(first, 1000)
      let assert Ok(first_state) = support.decode_room_state(first_state)

      let second =
        support.connect_websocket(
          support.server_port(server),
          "127.0.0.1",
          "http://127.0.0.1",
        )
      exception.defer(fn() { support.close_client(second) }, fn() {
        support.send_join(second, "Grace")
        let assert Ok(#(second_state, second)) =
          support.read_frame(second, 1000)
        let assert Ok(second_state) = support.decode_room_state(second_state)
        assert second_state.messages == []

        let assert Ok(#(joined_event, first)) = support.read_frame(first, 1000)
        let assert Ok(_) = support.decode_user_joined(joined_event)

        support.send_message(first, "Hello from Ada")
        let assert Ok(#(first_message, first)) = support.read_frame(first, 1000)
        let assert Ok(#(second_message, second)) =
          support.read_frame(second, 1000)
        let assert Ok(first_message) =
          support.decode_message_sent(first_message)
        let assert Ok(second_message) =
          support.decode_message_sent(second_message)

        assert first_message == second_message
        assert first_message.room_id == "default"
        assert first_message.message.sender_id == first_state.self_id
        assert first_message.message.username == "Ada"
        assert first_message.message.text == "Hello from Ada"
        assert first_message.message.sent_at != ""
        let assert Ok(_) =
          timestamp.parse_rfc3339(first_message.message.sent_at)
        assert second_state.self_id != first_state.self_id
        assert support.read_frame(first, 50) == Error(Nil)
        assert support.read_frame(second, 50) == Error(Nil)
      })
    })
  })
}

pub fn rate_limit_rejects_overflow_without_history_entry_test() {
  let server =
    support.start_server("test/fixtures/public", None, ["http://127.0.0.1"])

  exception.defer(fn() { support.stop_server(server) }, fn() {
    let first =
      support.connect_websocket(
        support.server_port(server),
        "127.0.0.1",
        "http://127.0.0.1",
      )
    exception.defer(fn() { support.close_client(first) }, fn() {
      support.send_join(first, "Ada")
      let assert Ok(#(state_payload, first)) = support.read_frame(first, 1000)
      let assert Ok(state) = support.decode_room_state(state_payload)

      send_messages(first, 1, 5)
      let #(first, accepted) = read_message_events(first, 5, [])
      assert list.length(accepted) == 5

      support.send_message(first, "message-6")
      let assert Ok(#(error_payload, _first)) = support.read_frame(first, 1000)
      let assert Ok(error) = support.decode_error(error_payload)
      assert error.code == "rate_limited"
      assert error.recoverable

      support.close_client(first)

      let reconnect =
        support.connect_websocket(
          support.server_port(server),
          "127.0.0.1",
          "http://127.0.0.1",
        )
      exception.defer(fn() { support.close_client(reconnect) }, fn() {
        support.send_join(reconnect, "Ada")
        let assert Ok(#(reconnect_payload, _reconnect)) =
          support.read_frame(reconnect, 1000)
        let assert Ok(reconnect_state) =
          support.decode_room_state(reconnect_payload)
        assert reconnect_state.self_id != state.self_id
        assert list.map(reconnect_state.messages, fn(message) { message.text })
          == ["message-1", "message-2", "message-3", "message-4", "message-5"]
      })
    })
  })
}

pub fn room_crash_notifies_clients_and_restarts_clean_state_test() {
  let server =
    support.start_server("test/fixtures/public", None, ["http://127.0.0.1"])
  let directory = support.server_directory(server)

  exception.defer(fn() { support.stop_server(server) }, fn() {
    let assert Ok(room_handle) =
      room_directory.resolve(directory, domain.default_room_id)
    let client =
      support.connect_websocket(
        support.server_port(server),
        "127.0.0.1",
        "http://127.0.0.1",
      )
    exception.defer(fn() { support.close_client(client) }, fn() {
      support.send_join(client, "Ada")
      let assert Ok(#(state_payload, client)) = support.read_frame(client, 1000)
      let assert Ok(state) = support.decode_room_state(state_payload)
      let old_room_pid = room.pid(room_handle)

      process.kill(old_room_pid)

      let assert Ok(#(error_payload, client)) = support.read_frame(client, 1000)
      let assert Ok(error) = support.decode_error(error_payload)
      assert error.code == "room_unavailable"
      assert !error.recoverable

      let assert Ok(#(websocket.Normal(_), _client)) =
        support.read_close_frame(client, 1000)

      let assert Ok(replacement) =
        wait_for_room_replacement(directory, old_room_pid, 1000)
      assert room.pid(replacement) != old_room_pid
      assert process.is_alive(room.pid(replacement))

      let reconnect =
        support.connect_websocket(
          support.server_port(server),
          "127.0.0.1",
          "http://127.0.0.1",
        )
      exception.defer(fn() { support.close_client(reconnect) }, fn() {
        support.send_join(reconnect, "Grace")
        let assert Ok(#(replacement_payload, _reconnect)) =
          support.read_frame(reconnect, 1000)
        let assert Ok(replacement_state) =
          support.decode_room_state(replacement_payload)
        assert replacement_state.self_id != state.self_id
        assert replacement_state.users
          == [support.WirePresence(replacement_state.self_id, "Grace")]
        assert replacement_state.messages == []
      })
    })
  })
}

fn wait_for_room_replacement(
  directory: room_directory.RoomDirectory,
  old_pid: process.Pid,
  retries_remaining: Int,
) -> Result(room.Room, Nil) {
  let replacement = case
    room_directory.resolve(directory, domain.default_room_id)
  {
    Ok(room_handle) ->
      case room.pid(room_handle) != old_pid {
        True -> Ok(room_handle)
        False -> Error(Nil)
      }
    Error(_) -> Error(Nil)
  }

  case replacement, retries_remaining {
    Ok(room_handle), _ -> Ok(room_handle)
    Error(_), retries_remaining if retries_remaining > 0 -> {
      process.sleep(1)
      wait_for_room_replacement(directory, old_pid, retries_remaining - 1)
    }
    Error(_), _ -> Error(Nil)
  }
}

fn send_messages(client: support.Client, next: Int, last: Int) -> Nil {
  case next > last {
    True -> Nil
    False -> {
      support.send_message(client, "message-" <> int.to_string(next))
      send_messages(client, next + 1, last)
    }
  }
}

fn read_message_events(
  client: support.Client,
  remaining: Int,
  messages: List(support.WireMessageEvent),
) -> #(support.Client, List(support.WireMessageEvent)) {
  case remaining {
    0 -> #(client, list.reverse(messages))
    _ -> {
      let assert Ok(#(payload, client)) = support.read_frame(client, 1000)
      let assert Ok(message) = support.decode_message_sent(payload)
      read_message_events(client, remaining - 1, [message, ..messages])
    }
  }
}
