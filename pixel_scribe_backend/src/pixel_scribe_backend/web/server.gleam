import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/option
import gleam/otp/static_supervisor.{type Supervisor}
import gleam/otp/supervision.{type ChildSpecification}
import gleam/result
import mist.{type Connection, type ResponseData}
import pixel_scribe_backend/user_registry

const index_html = "<html lang='en'>
  <head>
    <title>PIXEL SCRIBE</title>
  </head>
  <body>
    Hello, world!
  </body>
</html>
"

pub type Registration {
  Registered(name: String)
  RejectedDuplicate
}

fn reject_connection_duplicate() {
  let sbj = process.new_subject()
  let selector =
    process.new_selector()
    |> process.select(sbj)

  process.send(sbj, RejectedDuplicate)
  #(RejectedDuplicate, option.Some(selector))
}

pub fn new(
  bind_address: String,
  port: Int,
  user_registry_name: process.Name(user_registry.Message),
) -> ChildSpecification(Supervisor) {
  let not_found =
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  let not_authorized =
    response.new(401)
    |> response.set_body(mist.Bytes(bytes_tree.new()))

  fn(req: Request(Connection)) -> Response(ResponseData) {
    case request.path_segments(req) {
      [] ->
        response.new(200)
        |> response.set_body(mist.Bytes(bytes_tree.from_string(index_html)))
      ["ws"] -> {
        req
        |> request.get_header("x-name")
        |> result.map(fn(user_name) {
          mist.websocket(
            request: req,
            on_init: fn(_conn) {
              case
                process.call(
                  process.named_subject(user_registry_name),
                  100,
                  fn(subject) { user_registry.Add(subject, user_name) },
                )
              {
                "DUPLICATE_USERNAME" -> {
                  reject_connection_duplicate()
                }
                _ -> {
                  #(Registered(user_name), option.None)
                }
              }
            },
            on_close: fn(state) {
              case state {
                Registered(name) ->
                  process.send(
                    process.named_subject(user_registry_name),
                    user_registry.Remove(name),
                  )
                RejectedDuplicate -> Nil
              }
              io.println("WS disconnected!")
            },
            handler: handle_ws_message,
          )
        })
        |> result.unwrap(not_authorized)
      }

      _ -> not_found
    }
  }
  |> mist.new
  |> mist.bind(bind_address)
  |> mist.with_ipv6
  |> mist.port(port)
  |> mist.supervised
}

fn handle_ws_message(state, message, conn) {
  case state, message {
    RejectedDuplicate, mist.Custom(RejectedDuplicate) ->
      mist.stop_abnormal("username_taken")
    Registered(_), mist.Text(message) -> {
      let _ = mist.send_text_frame(conn, message)
      mist.continue(state)
    }
    _, mist.Closed | _, mist.Shutdown -> mist.stop()
    _, _ -> mist.continue(state)
  }
}
