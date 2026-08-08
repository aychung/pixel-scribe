import gleam/bytes_tree
import gleam/erlang/application
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/option.{None}
import gleam/otp/static_supervisor.{type Supervisor}
import gleam/otp/supervision.{type ChildSpecification}
import gleam/result
import gleam/string
import mist.{type Connection, type ResponseData}
import pixel_scribe_backend/chat/room
import pixel_scribe_backend/user_registry

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

fn get_public_file_path(file_path: String) -> String {
  let assert Ok(priv_dir) = application.priv_directory("pixel_scribe_backend")
  priv_dir <> "/public/" <> file_path
}

fn serve_file(
  _req: Request(Connection),
  file_path: List(String),
) -> Result(Response(ResponseData), _) {
  let file_path = get_public_file_path(string.join(file_path, "/"))

  // Omitting validation for brevity
  mist.send_file(file_path, offset: 0, limit: None)
  |> result.map(fn(file) {
    response.new(200)
    |> response.prepend_header("content-type", "text/html")
    |> response.set_body(file)
  })
}

pub fn new(
  bind_address: String,
  port: Int,
  user_registry_name: process.Name(user_registry.Message),
  room_registry_name: process.Name(room.Message),
) -> ChildSpecification(Supervisor) {
  let not_found =
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  let not_authorized =
    response.new(401)
    |> response.set_body(mist.Bytes(bytes_tree.new()))

  fn(req: Request(Connection)) -> Response(ResponseData) {
    case request.path_segments(req) {
      [] -> {
        io.println("> serving index html")
        serve_file(req, ["index.html"])
        |> result.unwrap(not_found)
      }

      ["ws", user_name] -> {
        mist.websocket(
          request: req,
          on_init: fn(conn) {
            case
              process.call(
                process.named_subject(user_registry_name),
                100,
                fn(subject) { user_registry.Add(subject, "user_name", conn) },
              )
            {
              "DUPLICATE_USERNAME" -> {
                reject_connection_duplicate()
              }
              _ -> {
                #(Registered("user_name"), None)
              }
            }
          },
          on_close: fn(state) {
            io.println("> ws: on close")
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
      }

      file_path ->
        serve_file(req, file_path)
        |> result.lazy_unwrap(fn() { not_found })
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
      io.println("> ws: handle message: " <> message)
      let _ = mist.send_text_frame(conn, message)
      mist.continue(state)
    }
    _, mist.Closed | _, mist.Shutdown -> mist.stop()
    _, _ -> mist.continue(state)
  }
}
