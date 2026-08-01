import gleam/bit_array
import gleam/bytes_tree
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/option
import gleam/otp/static_supervisor.{type Supervisor}
import gleam/otp/supervision.{type ChildSpecification}
import logging
import mist.{type Connection, type ResponseData}

const index_html = "<html lang='en'>
  <head>
    <title>PIXEL SCRIBE</title>
  </head>
  <body>
    Hello, world!
  </body>
</html>"

pub fn new(port: Int) -> ChildSpecification(Supervisor) {
  let not_found =
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_tree.new()))

  fn(req: Request(Connection)) -> Response(ResponseData) {
    let _ = case mist.get_connection_info(req.body) {
      Ok(info) -> {
        logging.log(
          logging.Info,
          "Got a request from: " <> mist.connection_info_to_string(info),
        )
      }
      Error(_nil) -> {
        logging.log(logging.Info, "Failed to get connection info")
      }
    }
    case request.path_segments(req) {
      [] ->
        response.new(200)
        |> response.prepend_header("my-value", "abc")
        |> response.prepend_header("my-value", "123")
        |> response.set_body(mist.Bytes(bytes_tree.from_string(index_html)))
      ["ws"] ->
        mist.websocket(
          request: req,
          on_init: fn(_conn) { #(Nil, option.None) },
          on_close: fn(_state) { io.println("WS disconnected!") },
          handler: handle_ws_message,
        )

      _ -> not_found
    }
  }
  |> mist.new
  |> mist.bind("localhost")
  |> mist.with_ipv6
  |> mist.port(port)
  |> mist.supervised
}

fn handle_ws_message(state, message, conn) {
  case message {
    mist.Text("ping") -> {
      let assert Ok(_) = mist.send_text_frame(conn, "pong")
      mist.continue(state)
    }
    mist.Text(msg) -> {
      logging.log(logging.Info, "Received text frame: " <> msg)
      mist.continue(state)
    }
    mist.Binary(msg) -> {
      logging.log(
        logging.Info,
        "Received binary frame ("
          <> int.to_string(bit_array.byte_size(msg))
          <> ")",
      )
      mist.continue(state)
    }
    mist.Custom(text) -> {
      let assert Ok(_) = mist.send_text_frame(conn, text)
      mist.continue(state)
    }
    mist.Closed | mist.Shutdown -> mist.stop()
  }
}
