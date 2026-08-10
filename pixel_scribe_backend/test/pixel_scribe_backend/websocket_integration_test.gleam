import exception
import gleam/bit_array
import gleam/bytes_tree
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/charlist
import gleam/erlang/process
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/static_supervisor
import gleam/string
import glisten/socket.{type Socket, type SocketReason}
import glisten/socket/options
import glisten/tcp
import gramps/websocket
import mist
import pixel_scribe_backend/domain
import pixel_scribe_backend/room
import pixel_scribe_backend/room_directory
import pixel_scribe_backend/web

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

type TestServer {
  TestServer(root: process.Pid, room: room.Room, port: Int)
}

type Client {
  Client(socket: Socket, buffer: BitArray)
}

type WireRoomState {
  WireRoomState(room_id: String, self_id: String, users: List(WirePresence))
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

fn start_test_server() -> TestServer {
  let port_subject = process.new_subject()
  let directory_name = room_directory.new_name()
  let directory = room_directory.from_name(directory_name)
  let web_child =
    web.mist_handler(directory, "test-secret-key")
    |> mist.new
    |> mist.port(0)
    |> mist.after_start(fn(port, _, _) { process.send(port_subject, port) })
    |> mist.supervised

  let assert Ok(started) =
    static_supervisor.new(static_supervisor.RestForOne)
    |> static_supervisor.add(room_directory.supervised(directory_name))
    |> static_supervisor.add(web_child)
    |> static_supervisor.start
  process.unlink(started.pid)

  let assert Ok(port) = process.receive(from: port_subject, within: 1000)
  let assert Ok(room_handle) = room.start(domain.default_room_id)
  process.unlink(room.pid(room_handle))
  let assert Ok(Nil) = room_directory.register(directory, room_handle)
  TestServer(started.pid, room_handle, port)
}

fn stop_test_server(server: TestServer) -> Nil {
  let TestServer(root, room_handle, _) = server
  process.kill(room.pid(room_handle))
  let _ = stop_supervisor(root)
  Nil
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

fn close_client(client: Client) -> Nil {
  let Client(socket, _) = client
  let _ = tcp.close(socket)
  Nil
}

fn read_frame(client: Client, timeout: Int) -> Result(#(String, Client), Nil) {
  let Client(socket, buffer) = client
  case bit_array.byte_size(buffer) {
    0 -> receive_more(socket, buffer, timeout)
    _ ->
      case websocket.decode_frame(buffer, None) {
        Error(websocket.NeedMoreData(_)) ->
          receive_more(socket, buffer, timeout)
        Error(websocket.InvalidFrame) -> Error(Nil)
        Ok(#(
          websocket.Complete(websocket.Data(websocket.TextFrame(payload))),
          rest,
        )) ->
          case bit_array.to_string(payload) {
            Ok(payload) -> Ok(#(payload, Client(socket, rest)))
            Error(Nil) -> Error(Nil)
          }
        Ok(_) -> Error(Nil)
      }
  }
}

fn receive_more(
  socket: Socket,
  buffer: BitArray,
  timeout: Int,
) -> Result(#(String, Client), Nil) {
  case tcp.receive_timeout(socket, 0, timeout) {
    Ok(chunk) ->
      read_frame(Client(socket, bit_array.append(buffer, chunk)), timeout)
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
  use messages <- decode.field("messages", decode.list(of: decode.dynamic))
  case event_type, messages {
    "room_state", [] -> decode.success(WireRoomState(room_id, self_id, users))
    "room_state", _ ->
      decode.failure(
        WireRoomState("", "", []),
        expected: "an empty message list",
      )
    _, _ ->
      decode.failure(WireRoomState("", "", []), expected: "a room_state event")
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

@external(erlang, "gen_tcp", "connect")
fn connect_tcp(
  address: charlist.Charlist,
  port: Int,
  options: List(options.ErlangTcpOption),
  timeout: Int,
) -> Result(Socket, SocketReason)

@external(erlang, "supervisor", "stop")
fn stop_supervisor(pid: process.Pid) -> Dynamic
