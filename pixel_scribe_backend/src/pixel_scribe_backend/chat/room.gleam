import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/otp/supervision
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import pixel_scribe_backend/user_registry.{type User}

pub type Chat {
  Chat(name: String, content: String, created_at: Timestamp)
}

/// Events sent from the room actor to WebSocket
pub type ClientEvent {
  Deliver(String)
  Disconnect
}

pub type RoomState {
  RoomState(
    chat_list: List(Chat),
    user_list: Dict(String, User),
    created_at: Timestamp,
  )
}

/// Message accepted by the room actor
pub type Message {
  Join(user: User, reply_to: Subject(Bool))
  Leave(user: User)
  Say(user: User, message: Chat)
}

pub fn new_actor() {
  actor.new(RoomState([], dict.new(), timestamp.system_time()))
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn supervised() {
  supervision.worker(fn() { new_actor() })
}

fn roomstate_to_string(state: RoomState) {
  "chat:\n"
  <> string.join(
    list.map(state.chat_list, fn(c: Chat) { "  - " <> c.content }),
    "\n",
  )
}

fn handle_message(state: RoomState, message: Message) {
  case message {
    Join(user, reply_to) -> {
      case dict.has_key(state.user_list, user.name) {
        True -> {
          process.send(reply_to, False)
          actor.continue(state)
        }
        False -> {
          let updated_user_list = dict.insert(state.user_list, user.name, user)
          let joined_chat =
            Chat(
              name: "system",
              content: ">>> " <> user.name <> " joined!!!",
              created_at: timestamp.system_time(),
            )
          let updated_chat_list = broadcast(state, joined_chat)
          let next =
            RoomState(updated_chat_list, updated_user_list, state.created_at)
          actor.continue(next)
        }
      }
    }
    _ -> {
      io.print(roomstate_to_string(state))
      actor.continue(state)
    }
  }
}

fn broadcast(state: RoomState, joined_chat: Chat) -> List(Chat) {
  dict.values(state.user_list)
  |> list.each(fn(user: User) { process.send(user.ws, Deliver(joined_chat)) })

  list.append(state.chat_list, joined_chat)
}
