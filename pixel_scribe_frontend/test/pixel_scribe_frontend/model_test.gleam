import gleam/option.{None}
import pixel_scribe_frontend/model
import pixel_scribe_frontend/update

pub fn initial_model_starts_in_username_choice_test() {
  assert model.initial()
    == model.Model(
      username_preference: "",
      username_input: "",
      phase: model.ChoosingUsername,
      room_id: None,
      draft: "",
      feedback: None,
      scene: model.Placeholder,
    )
}

pub fn username_input_updates_only_the_username_input_test() {
  let #(updated, _effect) =
    model.initial()
    |> update.update(update.UsernameInput("Ada"))

  assert updated
    == model.Model(
      username_preference: "",
      username_input: "Ada",
      phase: model.ChoosingUsername,
      room_id: None,
      draft: "",
      feedback: None,
      scene: model.Placeholder,
    )
}

pub fn submitting_username_preserves_the_current_model_test() {
  let initial = model.initial()
  let #(updated, _effect) = update.update(initial, update.SubmitUsername)

  assert updated == initial
}
