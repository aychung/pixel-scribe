import lustre/effect.{type Effect}

/// The only canvas node owned by the application.
pub const canvas_id = "office-canvas"

/// Safe status facts emitted by the native renderer boundary.
///
/// Dimensions are CSS content-box pixels and the scale is the browser's
/// validated device-pixel ratio. No DOM handles or browser error values cross
/// this boundary.
pub type Fact {
  Ready(width: Int, height: Int, dpr: Float)
  Resized(width: Int, height: Int, dpr: Float)
  Failed(reason: Error)
}

pub type Error {
  CanvasUnavailable
  ContextUnavailable
  ResizeObserverUnavailable
  GeometryUnavailable
  InitializationFailed
  Unknown
}

@external(javascript, "./canvas_ffi.mjs", "initialize_canvas")
fn initialize_canvas_ffi(
  on_ready: fn(Int, Int, Float) -> Nil,
  on_resize: fn(Int, Int, Float) -> Nil,
  on_error: fn(Int) -> Nil,
) -> Nil

@external(javascript, "./canvas_ffi.mjs", "dispose_canvas")
fn dispose_canvas_ffi() -> Nil

/// Initializes the one fixed renderer after Lustre has applied the latest
/// view. The effect is safe to run again: the native boundary reuses the same
/// handle and replaces only its message callbacks.
pub fn initialize() -> Effect(Fact) {
  effect.before_paint(fn(dispatch, _root) {
    initialize_canvas_ffi(
      fn(width, height, dpr) { dispatch(Ready(width, height, dpr)) },
      fn(width, height, dpr) { dispatch(Resized(width, height, dpr)) },
      fn(code) { dispatch(Failed(error_from_code(code))) },
    )
  })
}

/// Disposes the native renderer. The browser operation is deliberately
/// idempotent so every state-exit path can safely request cleanup.
pub fn dispose() -> Effect(a) {
  effect.from(fn(_dispatch) { dispose_canvas_ffi() })
}

fn error_from_code(code: Int) -> Error {
  case code {
    0 -> CanvasUnavailable
    1 -> ContextUnavailable
    2 -> ResizeObserverUnavailable
    3 -> GeometryUnavailable
    4 -> InitializationFailed
    _ -> Unknown
  }
}
