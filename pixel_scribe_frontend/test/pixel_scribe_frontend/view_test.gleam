import gleam/string
import lustre/element
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
