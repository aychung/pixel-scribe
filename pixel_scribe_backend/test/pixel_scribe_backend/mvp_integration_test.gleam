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
import gleam/result
import gleam/string
import gleam/time/timestamp
import glisten/socket.{type Socket, type SocketReason}
import glisten/socket/options
import glisten/tcp
import gramps/websocket
import mist
import pixel_scribe_backend/room_directory
import pixel_scribe_backend/room_factory
import pixel_scribe_backend/web

const test_key_base = "0123456789012345678901234567890123456789012345678901234567890123"

pub fn entry_page_and_static_assets_are_served_by_live_server_test() {
  let server = start_test_server()

  exception.defer(fn() { stop_test_server(server) }, fn() {
    let entry_page = get_http(server.port, "/")
    assert entry_page.status == 200
    assert response_header(entry_page.headers, "content-type")
      == Ok("text/html; charset=utf-8")
    assert response_header(entry_page.headers, "x-content-type-options")
      == Ok("nosniff")
    assert response_header(entry_page.headers, "x-frame-options") == Ok("DENY")
    assert string.contains(entry_page.body, "<title>Pixel Scribe</title>")

    let stylesheet = get_http(server.port, "/styles.css")
    assert stylesheet.status == 200
    assert response_header(stylesheet.headers, "content-type")
      == Ok("text/css; charset=utf-8")
    assert string.contains(stylesheet.body, "--chat-rail-width")

    let bundle = get_http(server.port, "/pixel_scribe_frontend.js")
    assert bundle.status == 200
    assert response_header(bundle.headers, "content-type")
      == Ok("text/javascript; charset=utf-8")
    assert string.contains(bundle.body, "Pixel Scribe")

    let missing_asset = get_http(server.port, "/missing.js")
    assert missing_asset.status == 404
  })
}

pub fn two_clients_complete_the_mvp_lifecycle_test() {
  let server = start_test_server()

  exception.defer(fn() { stop_test_server(server) }, fn() {
    let first = connect_websocket(server.port)

    exception.defer(fn() { close_client(first) }, fn() {
      send_join(first, "Ada")
      let assert Ok(#(first_payload, first)) = read_frame(first, 1000)
      let assert Ok(first_state) = decode_room_state(first_payload)

      assert first_state.room_id == "default"
      assert first_state.self_id != ""
      assert first_state.users == [WirePresence(first_state.self_id, "Ada")]
      assert first_state.messages == []

      let second = connect_websocket(server.port)

      exception.defer(fn() { close_client(second) }, fn() {
        send_join(second, "Grace")
        let assert Ok(#(second_payload, second)) = read_frame(second, 1000)
        let assert Ok(second_state) = decode_room_state(second_payload)

        assert second_state.room_id == "default"
        assert second_state.self_id != first_state.self_id
        assert second_state.users
          == [
            WirePresence(first_state.self_id, "Ada"),
            WirePresence(second_state.self_id, "Grace"),
          ]
        assert second_state.messages == []

        let assert Ok(#(joined_payload, first)) = read_frame(first, 1000)
        let assert Ok(joined) = decode_user_joined(joined_payload)
        assert joined.room_id == "default"
        assert joined.user == WirePresence(second_state.self_id, "Grace")
        assert read_frame(first, 50) == Error(Nil)

        send_message(first, "Hello from Ada")
        let assert Ok(#(first_message_payload, first)) = read_frame(first, 1000)
        let assert Ok(#(second_message_payload, second)) =
          read_frame(second, 1000)
        let assert Ok(first_message) =
          decode_message_sent(first_message_payload)
        let assert Ok(second_message) =
          decode_message_sent(second_message_payload)

        assert first_message == second_message
        assert first_message.room_id == "default"
        assert first_message.message.message_id != ""
        assert first_message.message.sender_id == first_state.self_id
        assert first_message.message.username == "Ada"
        assert first_message.message.text == "Hello from Ada"
        assert first_message.message.sent_at != ""
        let assert Ok(_) =
          timestamp.parse_rfc3339(first_message.message.sent_at)
        assert read_frame(first, 50) == Error(Nil)
        assert read_frame(second, 50) == Error(Nil)

        close_client(second)
        let assert Ok(#(left_payload, first)) = read_frame(first, 1000)
        let assert Ok(left) = decode_user_left(left_payload)
        assert left.room_id == "default"
        assert left.connection_id == second_state.self_id
        assert read_frame(first, 50) == Error(Nil)

        let reconnect = connect_websocket(server.port)

        exception.defer(fn() { close_client(reconnect) }, fn() {
          send_join(reconnect, "Grace")
          let assert Ok(#(reconnect_payload, _reconnect)) =
            read_frame(reconnect, 1000)
          let assert Ok(reconnect_state) = decode_room_state(reconnect_payload)

          assert reconnect_state.room_id == "default"
          assert reconnect_state.self_id != second_state.self_id
          assert reconnect_state.self_id != first_state.self_id
          assert reconnect_state.users
            == [
              WirePresence(first_state.self_id, "Ada"),
              WirePresence(reconnect_state.self_id, "Grace"),
            ]
          assert reconnect_state.messages == [first_message.message]

          let assert Ok(#(rejoined_payload, first)) = read_frame(first, 1000)
          let assert Ok(rejoined) = decode_user_joined(rejoined_payload)
          assert rejoined.room_id == "default"
          assert rejoined.user == WirePresence(reconnect_state.self_id, "Grace")
          assert read_frame(first, 50) == Error(Nil)
        })
      })
    })
  })
}

pub fn proxied_https_origin_is_accepted_by_configured_handler_test() {
  let server = start_test_server()

  exception.defer(fn() { stop_test_server(server) }, fn() {
    let client = connect_websocket(server.port)
    close_client(client)
  })
}

pub fn mismatched_origin_is_rejected_by_configured_handler_test() {
  let server = start_test_server()

  exception.defer(fn() { stop_test_server(server) }, fn() {
    assert websocket_status(server.port, "https://evil.example") == 403
  })
}

type TestServer {
  TestServer(root: process.Pid, port: Int)
}

type Client {
  Client(socket: Socket, buffer: BitArray)
}

type HttpResponse {
  HttpResponse(status: Int, headers: List(#(String, String)), body: String)
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

fn start_test_server() -> TestServer {
  let port_subject = process.new_subject()
  let directory_name = room_directory.new_name()
  let directory = room_directory.from_name(directory_name)
  let factory_name = room_factory.new_name()
  let web_child =
    web.mist_handler_with_options(
      directory,
      test_key_base,
      static_fixture_directory(),
      Some("https://example.test"),
      [],
    )
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
  TestServer(started.pid, port)
}

fn stop_test_server(server: TestServer) -> Nil {
  let TestServer(root, _) = server
  let _ = stop_supervisor(root)
  Nil
}

fn get_http(port: Int, path: String) -> HttpResponse {
  let socket = open_socket(port)
  let request =
    "GET "
    <> path
    <> " HTTP/1.1\r\n"
    <> "Host: 127.0.0.1\r\n"
    <> "Connection: close\r\n\r\n"
  let assert Ok(Nil) = tcp.send(socket, bytes_tree.from_string(request))
  let assert Ok(raw_response) = read_http_bytes(socket, <<>>)
  let _ = tcp.close(socket)
  let assert Ok(response) = decode_http_response(raw_response)
  response
}

fn read_http_bytes(socket: Socket, buffer: BitArray) -> Result(BitArray, Nil) {
  case tcp.receive_timeout(socket, 0, 1000) {
    Ok(chunk) -> read_http_bytes(socket, bit_array.append(buffer, chunk))
    Error(_) -> Ok(buffer)
  }
}

fn decode_http_response(raw: BitArray) -> Result(HttpResponse, Nil) {
  case bit_array.to_string(raw) {
    Error(Nil) -> Error(Nil)
    Ok(raw) ->
      case string.split_once(raw, on: "\r\n\r\n") {
        Error(Nil) -> Error(Nil)
        Ok(#(header_block, body)) -> {
          case string.split(header_block, on: "\r\n") {
            [status_line, ..header_lines] -> {
              use status <- result.try(parse_status_line(status_line))
              use headers <- result.try(list.try_map(
                header_lines,
                with: parse_header,
              ))
              Ok(HttpResponse(status, headers, body))
            }
            _ -> Error(Nil)
          }
        }
      }
  }
}

fn parse_status_line(line: String) -> Result(Int, Nil) {
  case string.split(line, on: " ") {
    [_, status, ..] ->
      case int.parse(status) {
        Ok(status) -> Ok(status)
        Error(_) -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn parse_header(line: String) -> Result(#(String, String), Nil) {
  case string.split_once(line, on: ": ") {
    Ok(#(name, value)) -> Ok(#(string.lowercase(name), value))
    Error(Nil) -> Error(Nil)
  }
}

fn response_header(
  headers: List(#(String, String)),
  name: String,
) -> Result(String, Nil) {
  list.key_find(headers, name)
}

fn static_fixture_directory() -> String {
  "test/fixtures/public"
}

fn connect_websocket(port: Int) -> Client {
  let socket = open_socket(port)
  let request = websocket_request("https://example.test")
  let assert Ok(Nil) = tcp.send(socket, bytes_tree.from_string(request))
  let assert Ok(rest) = read_handshake(socket, <<>>)
  Client(socket, rest)
}

fn websocket_status(port: Int, origin: String) -> Int {
  let socket = open_socket(port)
  let request = websocket_request(origin)
  let assert Ok(Nil) = tcp.send(socket, bytes_tree.from_string(request))
  let assert Ok(raw_response) = read_http_bytes(socket, <<>>)
  let _ = tcp.close(socket)
  let assert Ok(response) = decode_http_response(raw_response)
  response.status
}

fn websocket_request(origin: String) -> String {
  "GET /ws HTTP/1.1\r\n"
  <> "Host: example.test\r\n"
  <> "Origin: "
  <> origin
  <> "\r\n"
  <> "Upgrade: websocket\r\n"
  <> "Connection: Upgrade\r\n"
  <> "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
  <> "Sec-WebSocket-Version: 13\r\n\r\n"
}

fn open_socket(port: Int) -> Socket {
  let assert Ok(socket) =
    connect_tcp(
      charlist.from_string("127.0.0.1"),
      port,
      options.to_erl_options([
        options.Mode(options.Binary),
        options.ActiveMode(options.Passive),
        options.Nodelay(True),
      ]),
      1000,
    )
  socket
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

@external(erlang, "gen_tcp", "connect")
fn connect_tcp(
  address: charlist.Charlist,
  port: Int,
  options: List(options.ErlangTcpOption),
  timeout: Int,
) -> Result(Socket, SocketReason)

@external(erlang, "supervisor", "stop")
fn stop_supervisor(pid: process.Pid) -> Dynamic
