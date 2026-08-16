import gleam/option.{type Option, None}
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/placement
import pixel_scribe_frontend/scene as office_scene

/// The user-visible connection phases. A generation identifies one socket
/// lifetime; attempts count reconnects and reset only after a room snapshot.
pub type ConnectionPhase {
  ChoosingUsername
  Connecting(generation: Int, attempt: Int)
  AwaitingRoomState(generation: Int, attempt: Int)
  Joined(generation: Int, self_id: domain.ConnectionId)
  WaitingToReconnect(next_generation: Int, attempt: Int, delay_ms: Int)
  Blocked(reason: BlockReason)
}

pub type BlockReason {
  ProtocolFailure
  OfficeUnavailable
  RoomFull
}

pub type RoomSnapshot {
  RoomSnapshot(
    room_id: domain.RoomId,
    self_id: domain.ConnectionId,
    participants: List(domain.Presence),
    messages: List(domain.ChatMessage),
    stale: Bool,
  )
}

pub type SendInFlight {
  SendInFlight(generation: Int, text: String)
}

pub type ReconnectTimer {
  ReconnectTimer(generation: Int, timer_id: Int)
}

pub type SceneState {
  Placeholder
  Ready(
    seed: Int,
    self_id: domain.ConnectionId,
    placements: List(placement.Placement),
    render_data: office_scene.SceneRenderData,
    renderer_feedback: Option(String),
  )
  Failed(reason: String)
}

pub type Model {
  Model(
    username_preference: String,
    username_input: String,
    phase: ConnectionPhase,
    socket_generation: Int,
    placement_seed: Option(Int),
    room_snapshot: Option(RoomSnapshot),
    draft: String,
    send_in_flight: Option(SendInFlight),
    feedback: Option(String),
    connection_feedback: Option(String),
    reconnect_attempt: Int,
    reconnect_timer: Option(ReconnectTimer),
    rate_limit_until: Option(Int),
    scene: SceneState,
  )
}

pub fn initial() -> Model {
  Model(
    username_preference: "",
    username_input: "",
    phase: ChoosingUsername,
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
    scene: Placeholder,
  )
}
