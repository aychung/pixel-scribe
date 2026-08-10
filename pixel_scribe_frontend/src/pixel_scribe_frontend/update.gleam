import lustre/effect.{type Effect}
import pixel_scribe_frontend/model.{type Model}

pub type Msg {
  UsernameInput(value: String)
  SubmitUsername
}

pub fn update(model: Model, message: Msg) -> #(Model, Effect(Msg)) {
  case message {
    UsernameInput(value) -> #(
      model.Model(..model, username_input: value),
      effect.none(),
    )

    SubmitUsername -> #(model, effect.none())
  }
}
