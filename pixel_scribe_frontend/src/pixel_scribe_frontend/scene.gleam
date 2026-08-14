import gleam/int
import gleam/list
import gleam/order
import gleam/string
import pixel_scribe_frontend/domain

/// The logical pixel grid used by the office art and renderer.
pub const tile_size = 16

pub const world_tiles_width = 96

pub const world_tiles_height = 64

pub const world_pixel_width = 1536

pub const world_pixel_height = 1024

pub type TileExtent {
  TileExtent(width: Int, height: Int)
}

pub type WorldExtent {
  WorldExtent(width: Int, height: Int)
}

pub const world_tile_extent = TileExtent(
  width: world_tiles_width,
  height: world_tiles_height,
)

pub const world_pixel_extent = WorldExtent(
  width: world_pixel_width,
  height: world_pixel_height,
)

/// A point in logical office pixels. Its values are never CSS or device pixels.
pub type WorldPoint {
  WorldPoint(x: Int, y: Int)
}

/// A point in the logical viewport, after applying the camera transform.
pub type ViewportPoint {
  ViewportPoint(x: Int, y: Int)
}

/// A point measured in CSS pixels in the browser layout.
pub type CssPoint {
  CssPoint(x: Int, y: Int)
}

/// A point measured in device/backing-store pixels.
pub type DevicePoint {
  DevicePoint(x: Int, y: Int)
}

/// A world-space displacement, used for avatar visual metadata.
pub type WorldOffset {
  WorldOffset(dx: Int, dy: Int)
}

pub const avatar_bottom_center_offset = WorldOffset(dx: 0, dy: 0)

pub const avatar_visual_center_offset = WorldOffset(dx: 0, dy: -8)

pub type BubbleLimits {
  BubbleLimits(max_width: Int, max_lines: Int)
}

pub const bubble_limits = BubbleLimits(max_width: 160, max_lines: 3)

pub type ExclusionRect {
  ExclusionRect(left: Int, top: Int, width: Int, height: Int)
}

/// Keep anchors away from the outer wall so bubbles and avatars have room.
pub const edge_exclusions = [
  ExclusionRect(left: 0, top: 0, width: 64, height: world_pixel_height),
  ExclusionRect(left: 1472, top: 0, width: 64, height: world_pixel_height),
  ExclusionRect(left: 0, top: 0, width: world_pixel_width, height: 64),
  ExclusionRect(left: 0, top: 960, width: world_pixel_width, height: 64),
]

/// Furniture footprints are metadata only; no Canvas or browser code belongs here.
pub const furniture_exclusions = [
  ExclusionRect(left: 160, top: 176, width: 96, height: 80),
  ExclusionRect(left: 432, top: 336, width: 96, height: 80),
  ExclusionRect(left: 720, top: 672, width: 96, height: 80),
  ExclusionRect(left: 1008, top: 176, width: 96, height: 80),
  ExclusionRect(left: 1200, top: 496, width: 96, height: 80),
]

pub type Anchor {
  Anchor(index: Int, position: WorldPoint)
}

/// Renderer passes are data, not Canvas commands. Their order is the draw order.
pub type DrawPass {
  StaticFloorWalls
  Furniture
  Avatars
  NameSelfStatusAccents
  SpeechBubbles
}

pub const draw_passes = [
  StaticFloorWalls,
  Furniture,
  Avatars,
  NameSelfStatusAccents,
  SpeechBubbles,
]

pub type AvatarStatus {
  Online
  Reconnecting
}

/// Scene-owned renderer input. Identity is always the opaque connection ID.
pub type AvatarInput {
  AvatarInput(
    connection_id: domain.ConnectionId,
    username: String,
    bottom_anchor: WorldPoint,
    status: AvatarStatus,
  )
}

pub type AvatarVariant {
  AvatarVariant(index: Int)
}

pub type AvatarDraw {
  AvatarDraw(
    connection_id: domain.ConnectionId,
    username: String,
    bottom_anchor: WorldPoint,
    visual_center: WorldPoint,
    variant: AvatarVariant,
    is_self: Bool,
    status: AvatarStatus,
  )
}

pub type SceneRenderData {
  SceneRenderData(passes: List(DrawPass), avatars: List(AvatarDraw))
}

/// Fifty hand-authored, tile-aligned bottom-center positions in open floor.
/// The index is stable so placement can refer to an anchor without using a
/// participant's username or list position.
pub const curated_anchors = [
  Anchor(0, WorldPoint(128, 128)),
  Anchor(1, WorldPoint(272, 128)),
  Anchor(2, WorldPoint(416, 128)),
  Anchor(3, WorldPoint(560, 128)),
  Anchor(4, WorldPoint(704, 128)),
  Anchor(5, WorldPoint(848, 128)),
  Anchor(6, WorldPoint(992, 128)),
  Anchor(7, WorldPoint(1136, 128)),
  Anchor(8, WorldPoint(1280, 128)),
  Anchor(9, WorldPoint(1424, 128)),
  Anchor(10, WorldPoint(128, 304)),
  Anchor(11, WorldPoint(272, 304)),
  Anchor(12, WorldPoint(416, 304)),
  Anchor(13, WorldPoint(560, 304)),
  Anchor(14, WorldPoint(704, 304)),
  Anchor(15, WorldPoint(848, 304)),
  Anchor(16, WorldPoint(992, 304)),
  Anchor(17, WorldPoint(1136, 304)),
  Anchor(18, WorldPoint(1280, 304)),
  Anchor(19, WorldPoint(1424, 304)),
  Anchor(20, WorldPoint(128, 480)),
  Anchor(21, WorldPoint(272, 480)),
  Anchor(22, WorldPoint(416, 480)),
  Anchor(23, WorldPoint(560, 480)),
  Anchor(24, WorldPoint(704, 480)),
  Anchor(25, WorldPoint(848, 480)),
  Anchor(26, WorldPoint(992, 480)),
  Anchor(27, WorldPoint(1136, 480)),
  Anchor(28, WorldPoint(1280, 480)),
  Anchor(29, WorldPoint(1424, 480)),
  Anchor(30, WorldPoint(128, 656)),
  Anchor(31, WorldPoint(272, 656)),
  Anchor(32, WorldPoint(416, 656)),
  Anchor(33, WorldPoint(560, 656)),
  Anchor(34, WorldPoint(704, 656)),
  Anchor(35, WorldPoint(848, 656)),
  Anchor(36, WorldPoint(992, 656)),
  Anchor(37, WorldPoint(1136, 656)),
  Anchor(38, WorldPoint(1280, 656)),
  Anchor(39, WorldPoint(1424, 656)),
  Anchor(40, WorldPoint(128, 832)),
  Anchor(41, WorldPoint(272, 832)),
  Anchor(42, WorldPoint(416, 832)),
  Anchor(43, WorldPoint(560, 832)),
  Anchor(44, WorldPoint(704, 832)),
  Anchor(45, WorldPoint(848, 832)),
  Anchor(46, WorldPoint(992, 832)),
  Anchor(47, WorldPoint(1136, 832)),
  Anchor(48, WorldPoint(1280, 832)),
  Anchor(49, WorldPoint(1424, 832)),
]

pub fn anchor_points() -> List(WorldPoint) {
  list.map(curated_anchors, fn(anchor) { anchor.position })
}

pub fn anchor_is_walkable(point: WorldPoint) -> Bool {
  let WorldPoint(x, y) = point

  x % tile_size == 0
  && y % tile_size == 0
  && world_point_is_in_bounds(point)
  && !in_any_exclusion(point, edge_exclusions)
  && !in_any_exclusion(point, furniture_exclusions)
}

pub fn world_point_is_in_bounds(point: WorldPoint) -> Bool {
  let WorldPoint(x, y) = point
  x >= 0 && y >= 0 && x < world_pixel_width && y < world_pixel_height
}

pub fn point_is_in_exclusion(
  point: WorldPoint,
  exclusion: ExclusionRect,
) -> Bool {
  point_in_rect(point, exclusion)
}

pub fn avatar_visual_center(bottom_center: WorldPoint) -> WorldPoint {
  let WorldPoint(x, y) = bottom_center
  let WorldOffset(dx, dy) = avatar_visual_center_offset
  WorldPoint(x + dx, y + dy)
}

/// Select an avatar variant from only the page seed and opaque connection ID.
/// The bounded fold keeps JavaScript numbers well below unsafe integer sizes.
pub fn avatar_variant(
  seed: Int,
  connection_id: domain.ConnectionId,
) -> AvatarVariant {
  AvatarVariant(variant_index(seed, connection_id))
}

/// Build immutable renderer input in the fixed pass order and stable avatar order.
pub fn render_data(
  seed: Int,
  self_id: domain.ConnectionId,
  inputs: List(AvatarInput),
) -> SceneRenderData {
  let draws =
    list.map(inputs, fn(input) {
      AvatarDraw(
        connection_id: input.connection_id,
        username: input.username,
        bottom_anchor: input.bottom_anchor,
        visual_center: avatar_visual_center(input.bottom_anchor),
        variant: avatar_variant(seed, input.connection_id),
        is_self: input.connection_id == self_id,
        status: input.status,
      )
    })

  SceneRenderData(
    passes: draw_passes,
    avatars: list.sort(draws, by: compare_avatar_draws),
  )
}

const avatar_variant_count = 4

const avatar_variant_domain = 73

fn variant_index(seed: Int, connection_id: domain.ConnectionId) -> Int {
  let initial =
    positive_mod(
      positive_mod(seed, avatar_variant_count) + avatar_variant_domain,
      avatar_variant_count,
    )

  domain.connection_id_to_string(connection_id)
  |> string.to_utf_codepoints
  |> list.fold(initial, fn(hash, codepoint) {
    positive_mod(
      hash * 37 + string.utf_codepoint_to_int(codepoint) + avatar_variant_domain,
      avatar_variant_count,
    )
  })
}

fn positive_mod(value: Int, divisor: Int) -> Int {
  let remainder = value % divisor
  case remainder < 0 {
    True -> remainder + divisor
    False -> remainder
  }
}

fn compare_avatar_draws(left: AvatarDraw, right: AvatarDraw) -> order.Order {
  case int.compare(left.bottom_anchor.y, right.bottom_anchor.y) {
    order.Eq ->
      string.compare(
        domain.connection_id_to_string(left.connection_id),
        domain.connection_id_to_string(right.connection_id),
      )
    result -> result
  }
}

fn in_any_exclusion(
  point: WorldPoint,
  exclusions: List(ExclusionRect),
) -> Bool {
  list.any(exclusions, fn(exclusion) { point_in_rect(point, exclusion) })
}

fn point_in_rect(point: WorldPoint, rect: ExclusionRect) -> Bool {
  let WorldPoint(x, y) = point
  let ExclusionRect(left, top, width, height) = rect

  x >= left && x < left + width && y >= top && y < top + height
}
