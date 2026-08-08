import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/io
import gleam/option.{type Option, Some}
import gleam/otp/actor
import gleam/otp/supervision
import mist.{type WebsocketConnection}

pub type User {
  User(name: String, socket: Option(mist.WebsocketConnection))
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
  Add(process.Subject(String), String, WebsocketConnection)
  Remove(String)
}

pub fn handle_message(state: UserRegistryState, message: Message) {
  case message {
    Add(reply, name, socket) -> {
      io.println("> add user: " <> name)
      case dict.has_key(state.user_list, name) {
        True -> {
          process.send(reply, "DUPLICATE_USERNAME")
          actor.continue(state)
        }
        False -> {
          io.println("> adding user: " <> name)
          let new_user_list =
            dict.insert(state.user_list, name, User(name, Some(socket)))
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
