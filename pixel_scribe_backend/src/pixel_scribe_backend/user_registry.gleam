import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/supervision

pub type User {
  User(name: String)
}

pub type UserRegistryState {
  UserRegistryState(user_list: Dict(String, User))
}

pub fn new(name: process.Name(Message)) {
  actor.new(UserRegistryState(dict.new()))
  |> actor.named(name)
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn supervised(name: process.Name(Message)) {
  supervision.worker(fn() { new(name) })
}

pub type Message {
  Add(process.Subject(String), String)
  Remove(String)
}

pub fn handle_message(state: UserRegistryState, message: Message) {
  case message {
    Add(reply, name) -> {
      case dict.has_key(state.user_list, name) {
        True -> {
          process.send(reply, "DUPLICATE_USERNAME")
          actor.continue(state)
        }
        False -> {
          let new_user_list = dict.insert(state.user_list, name, User(name))
          process.send(reply, "DONE")
          actor.continue(UserRegistryState(new_user_list))
        }
      }
    }
    Remove(name) -> {
      let new_user_list = dict.delete(state.user_list, name)
      actor.continue(UserRegistryState(new_user_list))
    }
  }
}
