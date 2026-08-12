import gleam/option.{None, Some}
import pixel_scribe_frontend/model
import pixel_scribe_frontend/update

pub fn initial_model_starts_in_username_choice_test() {
  assert model.initial()
    == model.Model(
      username_preference: "",
      username_input: "",
      phase: model.ChoosingUsername,
      socket_generation: 0,
      placement_seed: None,
      room_snapshot: None,
      draft: "",
      send_in_flight: None,
      feedback: None,
      connection_feedback: None,
      reconnect_attempt: 0,
      reconnect_timer: None,
      rate_limit_until: None,
      scene: model.Placeholder,
    )
}

pub fn username_input_updates_only_the_username_input_test() {
  let #(updated, _effect) =
    model.initial()
    |> update.transition(update.UsernameInput("Ada"))

  assert updated
    == model.Model(
      username_preference: "",
      username_input: "Ada",
      phase: model.ChoosingUsername,
      socket_generation: 0,
      placement_seed: None,
      room_snapshot: None,
      draft: "",
      send_in_flight: None,
      feedback: None,
      connection_feedback: None,
      reconnect_attempt: 0,
      reconnect_timer: None,
      rate_limit_until: None,
      scene: model.Placeholder,
    )
}

pub fn submitting_empty_username_stays_local_with_feedback_test() {
  let initial = model.initial()
  let #(updated, _commands) = update.transition(initial, update.SubmitUsername)

  assert updated.phase == model.ChoosingUsername
  assert updated.socket_generation == initial.socket_generation
  assert updated.feedback == Some("Enter a username.")
}
