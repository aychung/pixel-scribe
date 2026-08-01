import gleam/otp/actor
import gleam/time/timestamp.{type Timestamp}
import pixel_scribe_backend/user_registry.{type User}

pub type Chat {
  Chat(name: String, content: String, created_at: Timestamp)
}

pub type RoomState {
  RoomState(chat_list: List(Chat), user_list: List(User), created_at: Timestamp)
}

pub type Message {
  AddUser(User)
}

pub fn new_actor(_) {
  actor.new(RoomState([], [], timestamp.system_time()))
  |> actor.on_message(handle_message)
  |> actor.start
}

fn handle_message(state: RoomState, message: Message) {
  case message {
    _ -> actor.continue(state)
  }
}
