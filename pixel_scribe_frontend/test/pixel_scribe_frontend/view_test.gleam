import gleam/string
import lustre/element
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/model
import pixel_scribe_frontend/update
import pixel_scribe_frontend/view

pub fn username_input_allows_32_graphemes_without_utf16_maxlength_test() {
  let username = string.repeat("😀", 32)
  let #(model, _) =
    update.update(model.initial(), update.UsernameInput(username))
  let rendered = element.to_string(view.view(model))

  assert string.contains(rendered, username)
  assert !string.contains(rendered, "maxlength")
}

pub fn username_view_connects_the_label_to_the_native_input_test() {
  let rendered = element.to_string(view.view(model.initial()))

  assert string.contains(rendered, "for=\"username\"")
  assert string.contains(rendered, "id=\"username\"")
}

pub fn username_view_exposes_connecting_and_awaiting_status_test() {
  let assert #(entered, []) =
    update.transition(model.initial(), update.UsernameInput("Ada"))
  let #(connecting, _) = update.transition(entered, update.SubmitUsername)
  let connecting_rendered = element.to_string(view.view(connecting))
  assert string.contains(connecting_rendered, "Connecting to the office")

  let #(awaiting, _) = update.transition(connecting, update.SocketOpened(1))
  let awaiting_rendered = element.to_string(view.view(awaiting))
  assert string.contains(awaiting_rendered, "Waiting for the office snapshot")
}

pub fn room_state_view_exposes_minimal_joined_status_test() {
  let self_id = domain.connection_id_from_string("self-1")
  let self_presence = domain.Presence(self_id, "Ada")
  let assert #(entered, []) =
    update.transition(model.initial(), update.UsernameInput("Ada"))
  let #(connecting, _) = update.transition(entered, update.SubmitUsername)
  let #(awaiting, _) = update.transition(connecting, update.SocketOpened(1))
  let #(joined, _) =
    update.transition(
      awaiting,
      update.ServerEvent(
        1,
        0,
        domain.RoomState(domain.default_room_id, self_id, [self_presence], []),
      ),
    )

  let rendered = element.to_string(view.view(joined))
  assert string.contains(rendered, "Joined the default office")
}
