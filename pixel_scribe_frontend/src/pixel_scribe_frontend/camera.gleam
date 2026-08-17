import gleam/int
import gleam/list
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/placement
import pixel_scribe_frontend/scene

/// The even logical viewport extent used by camera transforms.
pub type ViewportExtent {
  ViewportExtent(width: Int, height: Int)
}

pub const minimum_zoom = 1

pub const maximum_zoom = 3

pub const default_zoom = 2

pub type Camera {
  Camera(
    viewport: ViewportExtent,
    origin: scene.WorldPoint,
    self_id: domain.ConnectionId,
    zoom: Int,
    canvas_viewport: ViewportExtent,
  )
}

pub type CameraError {
  MissingSelf
}

/// Build a camera centered on the placement belonging to `self_id`.
pub fn new(
  viewport_width: Int,
  viewport_height: Int,
  self_id: domain.ConnectionId,
  placements: List(placement.Placement),
) -> Result(Camera, CameraError) {
  let canvas_viewport = normalized_viewport(viewport_width, viewport_height)

  build(canvas_viewport, self_id, placements, default_zoom)
}

/// Resize while retaining and recentering the current opaque self target.
pub fn resize(
  camera: Camera,
  viewport_width: Int,
  viewport_height: Int,
  placements: List(placement.Placement),
) -> Result(Camera, CameraError) {
  let Camera(_, _, self_id, zoom, _) = camera
  let canvas_viewport = normalized_viewport(viewport_width, viewport_height)

  build(canvas_viewport, self_id, placements, zoom)
}

/// Recenter immediately on a replacement self ID, such as after reconnect.
pub fn retarget(
  camera: Camera,
  self_id: domain.ConnectionId,
  placements: List(placement.Placement),
) -> Result(Camera, CameraError) {
  let Camera(_, _, _, zoom, canvas_viewport) = camera
  build(canvas_viewport, self_id, placements, zoom)
}

/// Recompute the same self target after a placement snapshot or peer change.
pub fn update(
  camera: Camera,
  placements: List(placement.Placement),
) -> Result(Camera, CameraError) {
  let Camera(_, _, self_id, zoom, canvas_viewport) = camera
  build(canvas_viewport, self_id, placements, zoom)
}

pub fn zoom_in(
  camera: Camera,
  placements: List(placement.Placement),
) -> Result(Camera, CameraError) {
  let next = int.min(maximum_zoom, zoom_level(camera) + 1)
  set_zoom(camera, next, placements)
}

pub fn zoom_out(
  camera: Camera,
  placements: List(placement.Placement),
) -> Result(Camera, CameraError) {
  let next = int.max(minimum_zoom, zoom_level(camera) - 1)
  set_zoom(camera, next, placements)
}

pub fn reset_zoom(
  camera: Camera,
  placements: List(placement.Placement),
) -> Result(Camera, CameraError) {
  set_zoom(camera, default_zoom, placements)
}

pub fn zoom_level(camera: Camera) -> Int {
  let Camera(_, _, _, zoom, _) = camera
  zoom
}

pub fn zoom_percent(camera: Camera) -> Int {
  zoom_level(camera) * 100
}

/// Transform one world-space point into logical viewport coordinates.
pub fn world_to_viewport(
  camera: Camera,
  point: scene.WorldPoint,
) -> scene.ViewportPoint {
  let Camera(_, origin, _, _, _) = camera
  let scene.WorldPoint(origin_x, origin_y) = origin
  let scene.WorldPoint(world_x, world_y) = point
  scene.ViewportPoint(world_x - origin_x, world_y - origin_y)
}

/// Transform one logical viewport point back into world-space coordinates.
pub fn viewport_to_world(
  camera: Camera,
  point: scene.ViewportPoint,
) -> scene.WorldPoint {
  let Camera(_, origin, _, _, _) = camera
  let scene.WorldPoint(origin_x, origin_y) = origin
  let scene.ViewportPoint(viewport_x, viewport_y) = point
  scene.WorldPoint(viewport_x + origin_x, viewport_y + origin_y)
}

fn set_zoom(
  camera: Camera,
  zoom: Int,
  placements: List(placement.Placement),
) -> Result(Camera, CameraError) {
  let Camera(_, _, self_id, _, canvas_viewport) = camera
  build(canvas_viewport, self_id, placements, zoom)
}

fn build(
  canvas_viewport: ViewportExtent,
  self_id: domain.ConnectionId,
  placements: List(placement.Placement),
  zoom: Int,
) -> Result(Camera, CameraError) {
  case visual_center_for(self_id, placements) {
    Ok(visual_center) -> {
      let viewport = viewport_at_zoom(canvas_viewport, zoom)
      Ok(Camera(
        viewport: viewport,
        origin: origin_for(visual_center, viewport),
        self_id: self_id,
        zoom: zoom,
        canvas_viewport: canvas_viewport,
      ))
    }
    Error(_) -> Error(MissingSelf)
  }
}

fn normalized_viewport(width: Int, height: Int) -> ViewportExtent {
  ViewportExtent(
    width: normalize_extent(width),
    height: normalize_extent(height),
  )
}

fn viewport_at_zoom(
  canvas_viewport: ViewportExtent,
  zoom: Int,
) -> ViewportExtent {
  let ViewportExtent(width, height) = canvas_viewport
  ViewportExtent(
    width: normalize_extent(width / zoom),
    height: normalize_extent(height / zoom),
  )
}

fn visual_center_for(
  self_id: domain.ConnectionId,
  placements: List(placement.Placement),
) -> Result(scene.WorldPoint, Nil) {
  case list.find(placements, fn(item) { item.connection_id == self_id }) {
    Ok(item) -> Ok(scene.avatar_visual_center(item.anchor.position))
    Error(_) -> Error(Nil)
  }
}

fn origin_for(
  visual_center: scene.WorldPoint,
  viewport: ViewportExtent,
) -> scene.WorldPoint {
  let scene.WorldPoint(center_x, center_y) = visual_center
  let ViewportExtent(width, height) = viewport
  scene.WorldPoint(center_x - width / 2, center_y - height / 2)
}

fn normalize_extent(value: Int) -> Int {
  case value <= 0 {
    True -> 0
    False -> value - value % 2
  }
}
