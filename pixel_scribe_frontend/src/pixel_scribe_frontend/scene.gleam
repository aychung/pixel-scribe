import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
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

/// Metrocity character cells are native 32×32 sprites with a bottom-center
/// anchor, so their visual center is 16 logical pixels above the anchor.
pub const avatar_visual_center_offset = WorldOffset(dx: 0, dy: -16)

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

/// A temporary, sender-owned message overlay. The message ID is the event
/// identity; sender ID is the ownership key used for replacement and leave.
pub type Bubble {
  Bubble(
    message_id: domain.MessageId,
    sender_id: domain.ConnectionId,
    text: String,
    started_at_ms: Int,
    expires_at_ms: Int,
  )
}

/// The deterministic lifecycle projection used by the renderer boundary.
/// `Fading` carries opacity as a percentage so fixed-clock tests do not need
/// floating-point comparisons.
pub type BubbleVisibility {
  FullyVisible
  Fading(opacity_percent: Int)
  Expired
}

pub type BubbleDeadline {
  BubbleDeadline(message_id: domain.MessageId, at_ms: Int)
}

/// The viewport-space rectangle used to draw a bubble. Coordinates are in
/// logical canvas pixels, before any device-pixel scaling.
pub type BubbleRect {
  BubbleRect(left: Int, top: Int, width: Int, height: Int)
}

/// Pure, renderer-independent bubble text and placement.
///
/// `lines` is only the bounded visual representation. `Bubble.text` retains
/// the full accepted value for future re-layout; chat state independently
/// supplies the full text to the accessible DOM log.
pub type BubbleLayout {
  BubbleLayout(lines: List(String), rectangle: BubbleRect, truncated: Bool)
}

pub type SceneRenderData {
  SceneRenderData(
    passes: List(DrawPass),
    avatars: List(AvatarDraw),
    bubbles: List(Bubble),
  )
}

/// Bubble visibility is six seconds: five seconds fully visible and one
/// second reserved for the later fade renderer.
pub const bubble_visible_ms = 5000

pub const bubble_fade_ms = 1000

pub const bubble_lifetime_ms = 6000

/// Bubble layout uses a conservative logical advance per grapheme. ASCII
/// graphemes use an 8px advance; every grapheme containing a non-ASCII
/// codepoint uses a 16px advance.
pub const bubble_glyph_width = 8

pub const bubble_horizontal_padding = 8

pub const bubble_vertical_padding = 4

pub const bubble_line_height = 12

pub const bubble_anchor_gap = 4

// Keep this derived token literal because Gleam constants cannot use
// arithmetic expressions: 160 - 8 - 8 = 144px of text interior.
const bubble_max_line_width = 144

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
  Anchor(99, WorldPoint(1424, 832)),
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
    bubbles: [],
  )
}

/// Add one live accepted message to the scene. Only a currently present sender
/// may own a bubble. Message IDs are idempotent, while a newer message from
/// the same sender replaces that sender's bubble.
pub fn add_bubble(
  data: SceneRenderData,
  message: domain.ChatMessage,
  started_at_ms: Int,
) -> SceneRenderData {
  let SceneRenderData(passes, avatars, bubbles) = data
  let sender_present =
    list.any(avatars, fn(avatar) { avatar.connection_id == message.sender_id })
  case
    sender_present,
    list.any(bubbles, fn(bubble) { bubble.message_id == message.message_id })
  {
    False, _ -> data
    _, True -> data
    True, False -> {
      let next =
        Bubble(
          message.message_id,
          message.sender_id,
          message.text,
          started_at_ms,
          started_at_ms + bubble_lifetime_ms,
        )
      SceneRenderData(
        passes,
        avatars,
        list.append(
          list.filter(bubbles, fn(bubble) {
            bubble.sender_id != message.sender_id
          }),
          [next],
        ),
      )
    }
  }
}

/// Return the lifecycle state at a fixed monotonic clock value.
pub fn bubble_visibility(
  bubble: Bubble,
  now_ms: Int,
  reduced_motion: Bool,
) -> BubbleVisibility {
  let Bubble(_, _, _, started_at_ms, expires_at_ms) = bubble
  let fade_starts_at_ms = started_at_ms + bubble_visible_ms
  case now_ms >= expires_at_ms {
    True -> Expired
    False ->
      case reduced_motion || now_ms < fade_starts_at_ms {
        True -> FullyVisible
        False -> {
          let elapsed_ms = now_ms - fade_starts_at_ms
          let remaining_ms = bubble_fade_ms - elapsed_ms
          let opacity_percent =
            int.max(1, int.min(100, remaining_ms * 100 / bubble_fade_ms))
          Fading(opacity_percent)
        }
      }
  }
}

/// Find the one lifecycle boundary that can change the current projection.
/// Expired bubbles have no deadline, allowing the renderer to go idle after
/// its final cleanup draw.
pub fn next_bubble_boundary(
  data: SceneRenderData,
  now_ms: Int,
  reduced_motion: Bool,
) -> Option(BubbleDeadline) {
  let SceneRenderData(_, _, bubbles) = data
  list.fold(bubbles, None, fn(current, bubble) {
    let Bubble(_, _, _, started_at_ms, expires_at_ms) = bubble
    let boundary = case bubble_visibility(bubble, now_ms, reduced_motion) {
      Expired -> None
      FullyVisible ->
        case reduced_motion {
          True -> Some(BubbleDeadline(bubble.message_id, expires_at_ms))
          False ->
            Some(BubbleDeadline(
              bubble.message_id,
              started_at_ms + bubble_visible_ms,
            ))
        }
      Fading(_) -> Some(BubbleDeadline(bubble.message_id, expires_at_ms))
    }
    choose_earliest(current, boundary)
  })
}

/// Remove bubbles whose expiry has been reached. Identity replacement is
/// naturally safe: the old message is no longer present in this list, so a
/// stale timer cannot remove the newer sender-owned bubble.
pub fn expire_bubbles(
  data: SceneRenderData,
  now_ms: Int,
  reduced_motion: Bool,
) -> SceneRenderData {
  let SceneRenderData(passes, avatars, bubbles) = data
  SceneRenderData(
    passes,
    avatars,
    list.filter(bubbles, fn(bubble) {
      bubble_visibility(bubble, now_ms, reduced_motion) != Expired
    }),
  )
}

fn choose_earliest(
  current: Option(BubbleDeadline),
  candidate: Option(BubbleDeadline),
) -> Option(BubbleDeadline) {
  case current, candidate {
    None, value -> value
    value, None -> value
    Some(existing), Some(next) ->
      case int.compare(existing.at_ms, next.at_ms) {
        order.Gt -> Some(next)
        _ -> Some(existing)
      }
  }
}

/// Lay out a bubble in logical viewport pixels.
///
/// Explicit LF boundaries are split first, then each resulting line is
/// wrapped into grapheme-safe chunks. At most three visual lines are retained;
/// only that visual projection receives an ellipsis. The rectangle is centred
/// over the owning avatar anchor and clamped against all viewport edges.
pub fn layout_bubble(
  bubble: Bubble,
  anchor: ViewportPoint,
  viewport_width: Int,
  viewport_height: Int,
) -> BubbleLayout {
  let explicit_lines = string.split(bubble.text, on: "\n")
  let wrapped_lines = wrap_explicit_lines(explicit_lines)
  let #(lines, truncated) = truncate_visual_lines(wrapped_lines)
  let line_count = int.max(1, list.length(lines))
  let longest_line_width =
    lines |> list.map(line_width) |> list.fold(0, int.max)
  let width =
    int.min(
      bubble_limits.max_width,
      int.max(
        bubble_glyph_width,
        longest_line_width + bubble_horizontal_padding * 2,
      ),
    )
  let height = line_count * bubble_line_height + bubble_vertical_padding * 2
  let safe_viewport_width = int.max(0, viewport_width)
  let safe_viewport_height = int.max(0, viewport_height)
  let rectangle_width = int.min(width, safe_viewport_width)
  let rectangle_height = int.min(height, safe_viewport_height)
  let ViewportPoint(anchor_x, anchor_y) = anchor
  let left =
    clamp(
      anchor_x - rectangle_width / 2,
      0,
      safe_viewport_width - rectangle_width,
    )
  let top =
    clamp(
      anchor_y - bubble_anchor_gap - rectangle_height,
      0,
      safe_viewport_height - rectangle_height,
    )

  BubbleLayout(
    lines,
    BubbleRect(left, top, rectangle_width, rectangle_height),
    truncated,
  )
}

fn wrap_explicit_lines(lines: List(String)) -> List(String) {
  list.fold(lines, [], fn(acc, line) { list.append(acc, wrap_line(line)) })
}

fn wrap_line(line: String) -> List(String) {
  case string.is_empty(line) {
    True -> [""]
    False -> wrap_graphemes(string.to_graphemes(line), [], 0, [])
  }
}

fn wrap_graphemes(
  remaining: List(String),
  current: List(String),
  current_width: Int,
  finished: List(String),
) -> List(String) {
  case remaining {
    [] ->
      case current {
        [] -> list.reverse(finished)
        _ ->
          list.reverse([
            string.join(list.reverse(current), with: ""),
            ..finished
          ])
      }
    [grapheme, ..rest] -> {
      let next_width = grapheme_width(grapheme)
      case current != [] && current_width + next_width > bubble_max_line_width {
        True ->
          wrap_graphemes(remaining, [], 0, [
            string.join(list.reverse(current), with: ""),
            ..finished
          ])
        False ->
          wrap_graphemes(
            rest,
            [grapheme, ..current],
            current_width + next_width,
            finished,
          )
      }
    }
  }
}

fn truncate_visual_lines(lines: List(String)) -> #(List(String), Bool) {
  case list.length(lines) <= bubble_limits.max_lines {
    True -> #(lines, False)
    False -> {
      let kept = list.take(lines, bubble_limits.max_lines)
      let assert Ok(last) = list.last(kept)
      let visual_last = line_with_ellipsis(last)
      let without_last = list.take(kept, bubble_limits.max_lines - 1)
      #(list.append(without_last, [visual_last]), True)
    }
  }
}

fn line_width(line: String) -> Int {
  line
  |> string.to_graphemes
  |> list.map(grapheme_width)
  |> list.fold(0, fn(total, width) { total + width })
}

fn grapheme_width(grapheme: String) -> Int {
  let codepoints = string.to_utf_codepoints(grapheme)
  case
    list.any(codepoints, fn(codepoint) {
      string.utf_codepoint_to_int(codepoint) > 127
    })
  {
    True -> 16
    False -> bubble_glyph_width
  }
}

fn line_with_ellipsis(line: String) -> String {
  let ellipsis = "..."
  let available_width = bubble_max_line_width - line_width(ellipsis)
  let prefix =
    take_graphemes_to_width(string.to_graphemes(line), available_width, 0, [])
  prefix <> ellipsis
}

fn take_graphemes_to_width(
  remaining: List(String),
  maximum_width: Int,
  current_width: Int,
  kept: List(String),
) -> String {
  case remaining {
    [] -> string.join(list.reverse(kept), with: "")
    [grapheme, ..rest] -> {
      let next_width = grapheme_width(grapheme)
      case current_width + next_width <= maximum_width {
        True ->
          take_graphemes_to_width(
            rest,
            maximum_width,
            current_width + next_width,
            [grapheme, ..kept],
          )
        False -> string.join(list.reverse(kept), with: "")
      }
    }
  }
}

fn clamp(value: Int, minimum: Int, maximum: Int) -> Int {
  int.max(minimum, int.min(value, maximum))
}

/// Keep existing bubbles only for participants still present. Room snapshots
/// intentionally call `render_data` and therefore start with no bubbles.
pub fn retain_bubbles(
  previous: SceneRenderData,
  data: SceneRenderData,
  participants: List(domain.Presence),
) -> SceneRenderData {
  let SceneRenderData(passes, avatars, _) = data
  let SceneRenderData(_, _, previous_bubbles) = previous
  SceneRenderData(
    passes,
    avatars,
    list.filter(previous_bubbles, fn(bubble) {
      list.any(participants, fn(participant) {
        participant.connection_id == bubble.sender_id
      })
    }),
  )
}

pub fn render_data_json_for_viewport(
  data: SceneRenderData,
  origin_x: Int,
  origin_y: Int,
  viewport_width: Int,
  viewport_height: Int,
) -> String {
  let SceneRenderData(_, avatars, bubbles) = data
  let rendered_bubbles =
    bubbles
    |> list.filter_map(fn(bubble) {
      bubble_layout_json(
        bubble,
        avatars,
        origin_x,
        origin_y,
        viewport_width,
        viewport_height,
      )
    })

  json.object([
    #("avatars", json.array(avatars, avatar_json)),
    #("bubbles", json.array(rendered_bubbles, fn(value) { value })),
  ])
  |> json.to_string
}

fn bubble_layout_json(
  bubble: Bubble,
  avatars: List(AvatarDraw),
  origin_x: Int,
  origin_y: Int,
  viewport_width: Int,
  viewport_height: Int,
) -> Result(json.Json, Nil) {
  case
    list.find(avatars, fn(avatar) { avatar.connection_id == bubble.sender_id })
  {
    Error(_) -> Error(Nil)
    Ok(avatar) -> {
      case
        avatar_is_visible_in_viewport(
          avatar,
          origin_x,
          origin_y,
          viewport_width,
          viewport_height,
        )
      {
        False -> Error(Nil)
        True -> {
          let AvatarDraw(_, _, WorldPoint(anchor_x, anchor_y), _, _, _, _) =
            avatar
          let layout =
            layout_bubble(
              bubble,
              ViewportPoint(anchor_x - origin_x, anchor_y - origin_y),
              viewport_width,
              viewport_height,
            )
          let BubbleLayout(lines, BubbleRect(left, top, width, height), _) =
            layout
          Ok(
            json.object([
              #(
                "id",
                json.string(domain.message_id_to_string(bubble.message_id)),
              ),
              #(
                "sender_id",
                json.string(domain.connection_id_to_string(bubble.sender_id)),
              ),
              #("lines", json.array(lines, json.string)),
              #("left", json.int(left)),
              #("top", json.int(top)),
              #("width", json.int(width)),
              #("height", json.int(height)),
              #("started_at_ms", json.int(bubble.started_at_ms)),
              #("expires_at_ms", json.int(bubble.expires_at_ms)),
            ]),
          )
        }
      }
    }
  }
}

fn avatar_is_visible_in_viewport(
  avatar: AvatarDraw,
  origin_x: Int,
  origin_y: Int,
  viewport_width: Int,
  viewport_height: Int,
) -> Bool {
  let AvatarDraw(_, _, WorldPoint(anchor_x, anchor_y), _, _, _, _) = avatar
  // Match the native Metrocity character destination rectangle: x-16..x+16
  // and y-32..y.
  let safe_width = int.max(0, viewport_width)
  let safe_height = int.max(0, viewport_height)
  let avatar_left = anchor_x - 16
  let avatar_top = anchor_y - 32
  let avatar_right = anchor_x + 16
  let avatar_bottom = anchor_y
  let viewport_right = origin_x + safe_width
  let viewport_bottom = origin_y + safe_height

  avatar_left < viewport_right
  && avatar_right > origin_x
  && avatar_top < viewport_bottom
  && avatar_bottom > origin_y
}

fn avatar_json(avatar: AvatarDraw) -> json.Json {
  let AvatarDraw(
    connection_id,
    username,
    WorldPoint(x, y),
    _,
    AvatarVariant(variant),
    is_self,
    status,
  ) = avatar
  json.object([
    #("id", json.string(domain.connection_id_to_string(connection_id))),
    #("username", json.string(username)),
    #("x", json.int(x)),
    #("y", json.int(y)),
    #("variant", json.int(variant)),
    #("self", json.bool(is_self)),
    #("status", json.string(status_name(status))),
  ])
}

fn status_name(status: AvatarStatus) -> String {
  case status {
    Online -> "online"
    Reconnecting -> "reconnecting"
  }
}

const avatar_variant_count = 32

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
