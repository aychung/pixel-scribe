import exception
import gleam/bit_array
import gleam/bytes_tree
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/charlist
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/static_supervisor
import gleam/string
import gleam/time/timestamp
import glisten/socket.{type Socket, type SocketReason}
import glisten/socket/options
import glisten/tcp
import gramps/websocket
import mist
import pixel_scribe_backend/domain
import pixel_scribe_backend/room
import pixel_scribe_backend/room_directory
import pixel_scribe_backend/room_factory
import pixel_scribe_backend/web

const test_key_base = "0123456789012345678901234567890123456789012345678901234567890123"

pub fn two_clients_join_and_disconnect_over_websocket_test() {
  let server = start_test_server()

  exception.defer(fn() { stop_test_server(server) }, fn() {
    let first = connect_websocket(server.port)

    exception.defer(fn() { close_client(first) }, fn() {
      send_join(first, "Ada")
      let assert Ok(#(first_state, first)) = read_frame(first, 1000)
      let assert Ok(first_state) = decode_room_state(first_state)
      assert first_state.room_id == "default"
      assert list.length(first_state.users) == 1
      assert first_state.users == [WirePresence(first_state.self_id, "Ada")]

      let second = connect_websocket(server.port)
      exception.defer(fn() { close_client(second) }, fn() {
        send_join(second, "Ada")
        let assert Ok(#(second_state, second)) = read_frame(second, 1000)
        let assert Ok(second_state) = decode_room_state(second_state)
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

        let assert Ok(#(joined_event, first)) = read_frame(first, 1000)
        let assert Ok(joined) = decode_user_joined(joined_event)
        assert joined.room_id == "default"
        assert joined.user == WirePresence(second_state.self_id, "Ada")
        assert read_frame(first, 50) == Error(Nil)

        close_client(second)
        let assert Ok(#(left_event, first)) = read_frame(first, 1000)
        let assert Ok(left) = decode_user_left(left_event)
        assert left.room_id == "default"
        assert left.connection_id == second_state.self_id
        assert read_frame(first, 50) == Error(Nil)
      })
    })
  })
}

pub fn accepted_messages_are_broadcast_with_server_metadata_test() {
  let server = start_test_server()

  exception.defer(fn() { stop_test_server(server) }, fn() {
    let first = connect_websocket(server.port)
    exception.defer(fn() { close_client(first) }, fn() {
      send_join(first, "Ada")
      let assert Ok(#(first_state, first)) = read_frame(first, 1000)
      let assert Ok(first_state) = decode_room_state(first_state)

      let second = connect_websocket(server.port)
      exception.defer(fn() { close_client(second) }, fn() {
        send_join(second, "Grace")
        let assert Ok(#(second_state, second)) = read_frame(second, 1000)
        let assert Ok(second_state) = decode_room_state(second_state)
        assert second_state.messages == []

        let assert Ok(#(joined_event, first)) = read_frame(first, 1000)
        let assert Ok(_) = decode_user_joined(joined_event)

        send_message(first, "Hello from Ada")
        let assert Ok(#(first_message, first)) = read_frame(first, 1000)
        let assert Ok(#(second_message, second)) = read_frame(second, 1000)
        let assert Ok(first_message) = decode_message_sent(first_message)
        let assert Ok(second_message) = decode_message_sent(second_message)

        assert first_message == second_message
        assert first_message.room_id == "default"
        assert first_message.message.sender_id == first_state.self_id
        assert first_message.message.username == "Ada"
        assert first_message.message.text == "Hello from Ada"
        assert first_message.message.sent_at != ""
        let assert Ok(_) =
          timestamp.parse_rfc3339(first_message.message.sent_at)
        assert second_state.self_id != first_state.self_id
        assert read_frame(first, 50) == Error(Nil)
        assert read_frame(second, 50) == Error(Nil)
      })
    })
  })
}

pub fn rate_limit_rejects_overflow_without_history_entry_test() {
  let server = start_test_server()

  exception.defer(fn() { stop_test_server(server) }, fn() {
    let first = connect_websocket(server.port)
    exception.defer(fn() { close_client(first) }, fn() {
      send_join(first, "Ada")
      let assert Ok(#(state_payload, first)) = read_frame(first, 1000)
      let assert Ok(state) = decode_room_state(state_payload)

      send_messages(first, 1, 5)
      let #(first, accepted) = read_message_events(first, 5, [])
      assert list.length(accepted) == 5

      send_message(first, "message-6")
      let assert Ok(#(error_payload, _first)) = read_frame(first, 1000)
      let assert Ok(error) = decode_error(error_payload)
      assert error.code == "rate_limited"
      assert error.recoverable

      close_client(first)

      let reconnect = connect_websocket(server.port)
      exception.defer(fn() { close_client(reconnect) }, fn() {
        send_join(reconnect, "Ada")
        let assert Ok(#(reconnect_payload, _reconnect)) =
          read_frame(reconnect, 1000)
        let assert Ok(reconnect_state) = decode_room_state(reconnect_payload)
        assert reconnect_state.self_id != state.self_id
        assert list.map(reconnect_state.messages, fn(message) { message.text })
          == ["message-1", "message-2", "message-3", "message-4", "message-5"]
      })
    })
  })
}

pub fn room_crash_notifies_clients_and_restarts_clean_state_test() {
  let server = start_test_server()

  exception.defer(fn() { stop_test_server(server) }, fn() {
    let client = connect_websocket(server.port)
    exception.defer(fn() { close_client(client) }, fn() {
      send_join(client, "Ada")
      let assert Ok(#(state_payload, client)) = read_frame(client, 1000)
      let assert Ok(state) = decode_room_state(state_payload)
      let old_room_pid = room.pid(server.room)

      process.kill(old_room_pid)

      let assert Ok(#(error_payload, client)) = read_frame(client, 1000)
      let assert Ok(error) = decode_error(error_payload)
      assert error.code == "room_unavailable"
      assert !error.recoverable

      let assert Ok(#(websocket.Normal(_), _client)) =
        read_close_frame(client, 1000)

      let assert Ok(replacement) =
        wait_for_room_replacement(server.directory, old_room_pid, 1000)
      assert room.pid(replacement) != old_room_pid
      assert process.is_alive(room.pid(replacement))

      let reconnect = connect_websocket(server.port)
      exception.defer(fn() { close_client(reconnect) }, fn() {
        send_join(reconnect, "Grace")
        let assert Ok(#(replacement_payload, _reconnect)) =
          read_frame(reconnect, 1000)
        let assert Ok(replacement_state) =
          decode_room_state(replacement_payload)
        assert replacement_state.self_id != state.self_id
        assert replacement_state.users
          == [WirePresence(replacement_state.self_id, "Grace")]
        assert replacement_state.messages == []
      })
    })
  })
}

type TestServer {
  TestServer(
    root: process.Pid,
    directory: room_directory.RoomDirectory,
    room: room.Room,
    port: Int,
  )
}

type Client {
  Client(socket: Socket, buffer: BitArray)
}

type WireRoomState {
  WireRoomState(
    room_id: String,
    self_id: String,
    users: List(WirePresence),
    messages: List(WireMessage),
  )
}

type WirePresence {
  WirePresence(connection_id: String, username: String)
}

type WireUserJoined {
  WireUserJoined(room_id: String, user: WirePresence)
}

type WireUserLeft {
  WireUserLeft(room_id: String, connection_id: String)
}

type WireMessageEvent {
  WireMessageEvent(room_id: String, message: WireMessage)
}

type WireMessage {
  WireMessage(
    message_id: String,
    sender_id: String,
    username: String,
    text: String,
    sent_at: String,
  )
}

type WireError {
  WireError(code: String, recoverable: Bool)
}

fn start_test_server() -> TestServer {
  let port_subject = process.new_subject()
  let directory_name = room_directory.new_name()
  let directory = room_directory.from_name(directory_name)
  let factory_name = room_factory.new_name()
  let web_child =
    web.mist_handler(directory, test_key_base)
    |> mist.new
    |> mist.port(0)
    |> mist.after_start(fn(port, _, _) { process.send(port_subject, port) })
    |> mist.supervised

  let assert Ok(started) =
    static_supervisor.new(static_supervisor.RestForOne)
    |> static_supervisor.add(room_directory.supervised(directory_name))
    |> static_supervisor.add(room_factory.supervised(directory, factory_name))
    |> static_supervisor.add(web_child)
    |> static_supervisor.start
  process.unlink(started.pid)

  let assert Ok(port) = process.receive(from: port_subject, within: 1000)
  let assert Ok(room_handle) =
    room_directory.resolve(directory, domain.default_room_id)
  TestServer(started.pid, directory, room_handle, port)
}

fn stop_test_server(server: TestServer) -> Nil {
  let TestServer(root, _, _, _) = server
  let _ = stop_supervisor(root)
  Nil
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

fn connect_websocket(port: Int) -> Client {
  let socket_options =
    options.to_erl_options([
      options.Mode(options.Binary),
      options.ActiveMode(options.Passive),
      options.Nodelay(True),
    ])
  let assert Ok(socket) =
    connect_tcp(charlist.from_string("127.0.0.1"), port, socket_options, 1000)
  let request =
    "GET /ws HTTP/1.1\r\n"
    <> "Host: 127.0.0.1\r\n"
    <> "Upgrade: websocket\r\n"
    <> "Connection: Upgrade\r\n"
    <> "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
    <> "Sec-WebSocket-Version: 13\r\n\r\n"
  let assert Ok(Nil) = tcp.send(socket, bytes_tree.from_string(request))
  let assert Ok(rest) = read_handshake(socket, <<>>)
  Client(socket, rest)
}

fn read_handshake(socket: Socket, buffer: BitArray) -> Result(BitArray, Nil) {
  case bit_array.to_string(buffer) {
    Error(Nil) -> Error(Nil)
    Ok(data) ->
      case string.split_once(data, on: "\r\n\r\n") {
        Ok(#(headers, rest)) -> {
          case string.starts_with(headers, "HTTP/1.1 101 ") {
            True -> Ok(bit_array.from_string(rest))
            False -> Error(Nil)
          }
        }
        Error(Nil) ->
          case tcp.receive_timeout(socket, 0, 1000) {
            Ok(chunk) -> read_handshake(socket, bit_array.append(buffer, chunk))
            Error(_) -> Error(Nil)
          }
      }
  }
}

fn send_join(client: Client, username: String) -> Nil {
  let Client(socket, _) = client
  let payload =
    "{\"type\":\"join_room\",\"room_id\":\"default\",\"username\":\""
    <> username
    <> "\"}"
  let frame = websocket.encode_text_frame(payload, None, Some(<<1, 2, 3, 4>>))
  let assert Ok(Nil) = tcp.send(socket, frame)
  Nil
}

fn send_message(client: Client, text: String) -> Nil {
  let Client(socket, _) = client
  let payload =
    "{\"type\":\"send_message\",\"room_id\":\"default\",\"text\":\""
    <> text
    <> "\"}"
  let frame = websocket.encode_text_frame(payload, None, Some(<<5, 6, 7, 8>>))
  let assert Ok(Nil) = tcp.send(socket, frame)
  Nil
}

fn close_client(client: Client) -> Nil {
  let Client(socket, _) = client
  let _ = tcp.close(socket)
  Nil
}

fn read_frame(client: Client, timeout: Int) -> Result(#(String, Client), Nil) {
  case read_websocket_frame(client, timeout) {
    Ok(#(websocket.Data(websocket.TextFrame(payload)), client)) ->
      case bit_array.to_string(payload) {
        Ok(payload) -> Ok(#(payload, client))
        Error(Nil) -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn read_close_frame(
  client: Client,
  timeout: Int,
) -> Result(#(websocket.CloseReason, Client), Nil) {
  case read_websocket_frame(client, timeout) {
    Ok(#(websocket.Control(websocket.CloseFrame(reason)), client)) ->
      Ok(#(reason, client))
    _ -> Error(Nil)
  }
}

fn read_websocket_frame(
  client: Client,
  timeout: Int,
) -> Result(#(websocket.Frame, Client), Nil) {
  let Client(socket, buffer) = client
  case bit_array.byte_size(buffer) {
    0 -> receive_websocket_frame(socket, buffer, timeout)
    _ ->
      case websocket.decode_frame(buffer, None) {
        Error(websocket.NeedMoreData(_)) ->
          receive_websocket_frame(socket, buffer, timeout)
        Error(websocket.InvalidFrame) -> Error(Nil)
        Ok(#(websocket.Complete(frame), rest)) ->
          Ok(#(frame, Client(socket, rest)))
        Ok(_) -> Error(Nil)
      }
  }
}

fn receive_websocket_frame(
  socket: Socket,
  buffer: BitArray,
  timeout: Int,
) -> Result(#(websocket.Frame, Client), Nil) {
  case tcp.receive_timeout(socket, 0, timeout) {
    Ok(chunk) ->
      read_websocket_frame(
        Client(socket, bit_array.append(buffer, chunk)),
        timeout,
      )
    Error(_) -> Error(Nil)
  }
}

fn decode_room_state(payload: String) -> Result(WireRoomState, Nil) {
  json.parse(payload, using: room_state_decoder())
  |> result_replace_error()
}

fn decode_user_joined(payload: String) -> Result(WireUserJoined, Nil) {
  json.parse(payload, using: user_joined_decoder())
  |> result_replace_error()
}

fn decode_user_left(payload: String) -> Result(WireUserLeft, Nil) {
  json.parse(payload, using: user_left_decoder())
  |> result_replace_error()
}

fn decode_message_sent(payload: String) -> Result(WireMessageEvent, Nil) {
  json.parse(payload, using: message_sent_decoder())
  |> result_replace_error()
}

fn decode_error(payload: String) -> Result(WireError, Nil) {
  json.parse(payload, using: error_decoder())
  |> result_replace_error()
}

fn result_replace_error(value: Result(a, b)) -> Result(a, Nil) {
  case value {
    Ok(value) -> Ok(value)
    Error(_) -> Error(Nil)
  }
}

fn room_state_decoder() -> decode.Decoder(WireRoomState) {
  use event_type <- decode.field("type", decode.string)
  use room_id <- decode.field("room_id", decode.string)
  use self_id <- decode.field("self_id", decode.string)
  use users <- decode.field("users", decode.list(of: presence_decoder()))
  use messages <- decode.field("messages", decode.list(of: message_decoder()))
  case event_type {
    "room_state" ->
      decode.success(WireRoomState(room_id, self_id, users, messages))
    _ ->
      decode.failure(
        WireRoomState("", "", [], []),
        expected: "a room_state event",
      )
  }
}

fn presence_decoder() -> decode.Decoder(WirePresence) {
  use connection_id <- decode.field("connection_id", decode.string)
  use username <- decode.field("username", decode.string)
  decode.success(WirePresence(connection_id, username))
}

fn user_joined_decoder() -> decode.Decoder(WireUserJoined) {
  use event_type <- decode.field("type", decode.string)
  use room_id <- decode.field("room_id", decode.string)
  use user <- decode.field("user", presence_decoder())
  case event_type {
    "user_joined" -> decode.success(WireUserJoined(room_id, user))
    _ ->
      decode.failure(
        WireUserJoined("", WirePresence("", "")),
        expected: "a user_joined event",
      )
  }
}

fn user_left_decoder() -> decode.Decoder(WireUserLeft) {
  use event_type <- decode.field("type", decode.string)
  use room_id <- decode.field("room_id", decode.string)
  use connection_id <- decode.field("connection_id", decode.string)
  case event_type {
    "user_left" -> decode.success(WireUserLeft(room_id, connection_id))
    _ -> decode.failure(WireUserLeft("", ""), expected: "a user_left event")
  }
}

fn message_sent_decoder() -> decode.Decoder(WireMessageEvent) {
  use event_type <- decode.field("type", decode.string)
  use room_id <- decode.field("room_id", decode.string)
  use message <- decode.field("message", message_decoder())
  case event_type {
    "message_sent" -> decode.success(WireMessageEvent(room_id, message))
    _ ->
      decode.failure(
        WireMessageEvent("", WireMessage("", "", "", "", "")),
        expected: "a message_sent event",
      )
  }
}

fn message_decoder() -> decode.Decoder(WireMessage) {
  use message_id <- decode.field("message_id", decode.string)
  use sender_id <- decode.field("sender_id", decode.string)
  use username <- decode.field("username", decode.string)
  use text <- decode.field("text", decode.string)
  use sent_at <- decode.field("sent_at", decode.string)
  decode.success(WireMessage(message_id, sender_id, username, text, sent_at))
}

fn error_decoder() -> decode.Decoder(WireError) {
  use event_type <- decode.field("type", decode.string)
  use code <- decode.field("code", decode.string)
  use recoverable <- decode.field("recoverable", decode.bool)
  case event_type {
    "error" -> decode.success(WireError(code, recoverable))
    _ -> decode.failure(WireError("", False), expected: "an error event")
  }
}

fn send_messages(client: Client, next: Int, last: Int) -> Nil {
  case next > last {
    True -> Nil
    False -> {
      send_message(client, "message-" <> int.to_string(next))
      send_messages(client, next + 1, last)
    }
  }
}

fn read_message_events(
  client: Client,
  remaining: Int,
  messages: List(WireMessageEvent),
) -> #(Client, List(WireMessageEvent)) {
  case remaining {
    0 -> #(client, list.reverse(messages))
    _ -> {
      let assert Ok(#(payload, client)) = read_frame(client, 1000)
      let assert Ok(message) = decode_message_sent(payload)
      read_message_events(client, remaining - 1, [message, ..messages])
    }
  }
}

@external(erlang, "gen_tcp", "connect")
fn connect_tcp(
  address: charlist.Charlist,
  port: Int,
  options: List(options.ErlangTcpOption),
  timeout: Int,
) -> Result(Socket, SocketReason)

@external(erlang, "supervisor", "stop")
fn stop_supervisor(pid: process.Pid) -> Dynamic
