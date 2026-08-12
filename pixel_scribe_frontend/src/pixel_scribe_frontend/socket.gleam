import lustre/effect.{type Effect}

/// Facts emitted by one native WebSocket lifetime.
///
/// The generation is retained on every callback so a later state machine can
/// discard callbacks from an older socket. Message payloads are still raw
/// text at this boundary; protocol decoding belongs to the next layer.
pub type Fact {
  Opened(generation: Int)
  Message(generation: Int, received_at_ms: Int, payload: String)
  NonTextFrame(generation: Int)
  Error(generation: Int, random_unit: Float)
  Closed(generation: Int, deliberate: Bool, random_unit: Float)
}

@external(javascript, "./socket_ffi.mjs", "location_protocol")
fn location_protocol_ffi() -> String

@external(javascript, "./socket_ffi.mjs", "location_host")
fn location_host_ffi() -> String

@external(javascript, "./socket_ffi.mjs", "open_socket")
fn open_socket_ffi(
  generation: Int,
  url: String,
  on_open: fn(Int) -> Nil,
  on_message: fn(Int, String) -> Nil,
  on_non_text_frame: fn(Int) -> Nil,
  on_error: fn(Int) -> Nil,
  on_close: fn(Int, Bool) -> Nil,
) -> Nil

@external(javascript, "./socket_ffi.mjs", "send_socket")
fn send_socket_ffi(generation: Int, text: String) -> Nil

@external(javascript, "./socket_ffi.mjs", "close_socket")
fn close_socket_ffi(generation: Int) -> Nil

@external(javascript, "./socket_ffi.mjs", "now_ms")
fn now_ms_ffi() -> Int

@external(javascript, "./socket_ffi.mjs", "random_unit")
fn random_unit_ffi() -> Float

/// Derives the only permitted production endpoint from the page origin.
///
/// `host` is `window.location.host`, including an explicit port when one is
/// present. The path is intentionally fixed to the backend's same-origin `/ws`
/// endpoint; callers cannot provide a cross-origin override.
pub fn websocket_url(protocol: String, host: String) -> String {
  let scheme = case protocol {
    "https:" -> "wss://"
    _ -> "ws://"
  }

  scheme <> host <> "/ws"
}

/// Opens one native socket for `generation` and dispatches typed facts.
pub fn open(generation: Int) -> Effect(Fact) {
  effect.from(fn(dispatch) {
    let url = websocket_url(location_protocol_ffi(), location_host_ffi())

    open_socket_ffi(
      generation,
      url,
      fn(callback_generation) { dispatch(Opened(callback_generation)) },
      fn(callback_generation, payload) {
        dispatch(Message(callback_generation, now_ms_ffi(), payload))
      },
      fn(callback_generation) { dispatch(NonTextFrame(callback_generation)) },
      fn(callback_generation) {
        dispatch(Error(callback_generation, random_unit_ffi()))
      },
      fn(callback_generation, deliberate) {
        dispatch(Closed(callback_generation, deliberate, random_unit_ffi()))
      },
    )
  })
}

/// Sends one already-serialized text frame through the socket generation.
/// Serialization, size checks, and protocol validation remain outside this
/// transport module.
pub fn send(generation: Int, text: String) -> Effect(a) {
  effect.from(fn(_dispatch) { send_socket_ffi(generation, text) })
}

/// Deliberately closes the socket generation. The native close callback is
/// marked deliberate and remains generation-tagged.
pub fn close(generation: Int) -> Effect(a) {
  effect.from(fn(_dispatch) { close_socket_ffi(generation) })
}
