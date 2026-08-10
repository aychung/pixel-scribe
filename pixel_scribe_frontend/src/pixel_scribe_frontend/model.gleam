import gleam/option.{type Option, None}

pub type ConnectionPhase {
  ChoosingUsername
}

pub type SceneState {
  Placeholder
}

pub type Model {
  Model(
    username_preference: String,
    username_input: String,
    phase: ConnectionPhase,
    room_id: Option(String),
    draft: String,
    feedback: Option(String),
    scene: SceneState,
  )
}

pub fn initial() -> Model {
  Model(
    username_preference: "",
    username_input: "",
    phase: ChoosingUsername,
    room_id: None,
    draft: "",
    feedback: None,
    scene: Placeholder,
  )
}
