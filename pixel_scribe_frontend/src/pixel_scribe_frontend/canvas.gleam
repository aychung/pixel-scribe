import gleam/json
import lustre/effect.{type Effect}
import pixel_scribe_frontend/camera
import pixel_scribe_frontend/scene

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
  AssetUnavailable
  SceneUnavailable
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

@external(javascript, "./canvas_ffi.mjs", "render_canvas")
fn render_canvas_ffi(
  scene_json: String,
  camera_json: String,
  on_error: fn(Int) -> Nil,
) -> Nil

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

/// Sends one trusted scene snapshot to the active renderer. The native side
/// validates the JSON again because browser and FFI values are untrusted.
pub fn render(
  data: scene.SceneRenderData,
  state: camera.Camera,
) -> Effect(Fact) {
  let scene_json = scene.render_data_json(data)
  let camera_json = camera_json(state)
  effect.from(fn(dispatch) {
    render_canvas_ffi(scene_json, camera_json, fn(code) {
      dispatch(Failed(error_from_code(code)))
    })
  })
}

fn camera_json(state: camera.Camera) -> String {
  let camera.Camera(
    camera.ViewportExtent(width, height),
    scene.WorldPoint(origin_x, origin_y),
    _,
    zoom,
    _,
  ) = state
  json.object([
    #("origin_x", json.int(origin_x)),
    #("origin_y", json.int(origin_y)),
    #("viewport_width", json.int(width)),
    #("viewport_height", json.int(height)),
    #("zoom", json.int(zoom)),
  ])
  |> json.to_string
}

fn error_from_code(code: Int) -> Error {
  case code {
    0 -> CanvasUnavailable
    1 -> ContextUnavailable
    2 -> ResizeObserverUnavailable
    3 -> GeometryUnavailable
    4 -> InitializationFailed
    5 -> AssetUnavailable
    6 -> SceneUnavailable
    _ -> Unknown
  }
}
