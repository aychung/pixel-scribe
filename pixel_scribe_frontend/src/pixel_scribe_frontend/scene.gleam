import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string
import pixel_scribe_frontend/domain

/// The logical pixel grid used by the office art and renderer.
pub const tile_size = 16

/// The office follows Pixel Agents' compact 21×11 interior footprint: a
/// workroom on the left, a lounge on the right, and a central opening.
pub const world_tiles_width = 21

pub const world_tiles_height = 11

pub const world_pixel_width = 336

pub const world_pixel_height = 176

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

/// Every rendered avatar uses one 16×16 compact sprite cell.
pub const avatar_size = 16

pub const avatar_visual_center_offset = WorldOffset(dx: 0, dy: -8)

pub type BubbleLimits {
  BubbleLimits(max_width: Int, max_lines: Int)
}

pub const bubble_limits = BubbleLimits(max_width: 160, max_lines: 3)

pub type ExclusionRect {
  ExclusionRect(left: Int, top: Int, width: Int, height: Int)
}

/// Keep anchors away from the outer wall and the divider between the rooms.
pub const edge_exclusions = [
  ExclusionRect(left: 0, top: 0, width: 16, height: world_pixel_height),
  ExclusionRect(left: 320, top: 0, width: 16, height: world_pixel_height),
  ExclusionRect(left: 0, top: 0, width: world_pixel_width, height: 16),
  ExclusionRect(left: 0, top: 160, width: world_pixel_width, height: 16),
  ExclusionRect(left: 160, top: 16, width: 16, height: 48),
  ExclusionRect(left: 160, top: 128, width: 16, height: 32),
]

/// Blocking furniture footprints mirror `ROOM_LAYOUT` in the Canvas renderer.
/// Rugs and wall decorations are walkable backdrops drawn behind avatars.
/// This metadata contains no Canvas or browser code.
pub const furniture_exclusions = [
  ExclusionRect(left: 32, top: 32, width: 64, height: 96),
  ExclusionRect(left: 96, top: 32, width: 64, height: 96),
  ExclusionRect(left: 32, top: 96, width: 64, height: 64),
  ExclusionRect(left: 96, top: 96, width: 64, height: 64),
  ExclusionRect(left: 64, top: 96, width: 64, height: 96),
  ExclusionRect(left: 48, top: 96, width: 64, height: 64),
  ExclusionRect(left: 48, top: 128, width: 64, height: 64),
  ExclusionRect(left: 112, top: 96, width: 64, height: 64),
  ExclusionRect(left: 112, top: 128, width: 64, height: 64),
  ExclusionRect(left: 208, top: 64, width: 64, height: 64),
  ExclusionRect(left: 224, top: 48, width: 64, height: 64),
  ExclusionRect(left: 224, top: 96, width: 64, height: 64),
  ExclusionRect(left: 256, top: 64, width: 64, height: 64),
  ExclusionRect(left: 224, top: 64, width: 64, height: 64),
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

/// Fifty hand-authored bottom-center positions on the compact avatar lattice.
pub const curated_anchors = [
  Anchor(0, WorldPoint(24, 32)),
  Anchor(1, WorldPoint(40, 32)),
  Anchor(2, WorldPoint(56, 32)),
  Anchor(3, WorldPoint(72, 32)),
  Anchor(4, WorldPoint(88, 32)),
  Anchor(5, WorldPoint(104, 32)),
  Anchor(6, WorldPoint(120, 32)),
  Anchor(7, WorldPoint(136, 32)),
  Anchor(8, WorldPoint(152, 32)),
  Anchor(9, WorldPoint(184, 32)),
  Anchor(10, WorldPoint(200, 32)),
  Anchor(11, WorldPoint(216, 32)),
  Anchor(12, WorldPoint(232, 32)),
  Anchor(13, WorldPoint(248, 32)),
  Anchor(14, WorldPoint(264, 32)),
  Anchor(15, WorldPoint(280, 32)),
  Anchor(16, WorldPoint(296, 32)),
  Anchor(17, WorldPoint(312, 32)),
  Anchor(18, WorldPoint(24, 48)),
  Anchor(19, WorldPoint(184, 48)),
  Anchor(20, WorldPoint(200, 48)),
  Anchor(21, WorldPoint(216, 48)),
  Anchor(22, WorldPoint(232, 48)),
  Anchor(23, WorldPoint(248, 48)),
  Anchor(24, WorldPoint(264, 48)),
  Anchor(25, WorldPoint(280, 48)),
  Anchor(26, WorldPoint(296, 48)),
  Anchor(27, WorldPoint(312, 48)),
  Anchor(28, WorldPoint(24, 64)),
  Anchor(29, WorldPoint(184, 64)),
  Anchor(30, WorldPoint(200, 64)),
  Anchor(31, WorldPoint(216, 64)),
  Anchor(32, WorldPoint(296, 64)),
  Anchor(33, WorldPoint(312, 64)),
  Anchor(34, WorldPoint(24, 80)),
  Anchor(35, WorldPoint(168, 80)),
  Anchor(36, WorldPoint(184, 80)),
  Anchor(37, WorldPoint(200, 80)),
  Anchor(38, WorldPoint(24, 96)),
  Anchor(39, WorldPoint(168, 96)),
  Anchor(40, WorldPoint(184, 96)),
  Anchor(41, WorldPoint(200, 96)),
  Anchor(42, WorldPoint(24, 112)),
  Anchor(43, WorldPoint(184, 112)),
  Anchor(44, WorldPoint(200, 112)),
  Anchor(45, WorldPoint(24, 128)),
  Anchor(46, WorldPoint(184, 128)),
  Anchor(47, WorldPoint(200, 128)),
  Anchor(48, WorldPoint(24, 144)),
  Anchor(49, WorldPoint(184, 144)),
]

pub fn anchor_points() -> List(WorldPoint) {
  list.map(curated_anchors, fn(anchor) { anchor.position })
}

pub fn anchor_is_walkable(point: WorldPoint) -> Bool {
  let WorldPoint(x, y) = point

  x % tile_size == avatar_size / 2
  && y % tile_size == 0
  && anchor_has_clear_footprint(Anchor(-1, point))
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

/// The half-open rectangle occupied by one compact avatar cell.
/// Rectangles that only touch at an edge do not overlap.
pub fn rectangles_intersect(left: ExclusionRect, right: ExclusionRect) -> Bool {
  left.left < right.left + right.width
  && left.left + left.width > right.left
  && left.top < right.top + right.height
  && left.top + left.height > right.top
}

pub fn anchor_has_clear_footprint(anchor: Anchor) -> Bool {
  let rect = avatar_rect(anchor.position)
  rect.left >= 0
  && rect.top >= 0
  && rect.left + rect.width <= world_pixel_width
  && rect.top + rect.height <= world_pixel_height
  && !list.any(edge_exclusions, fn(wall) { rectangles_intersect(rect, wall) })
  && !list.any(furniture_exclusions, fn(furniture) {
    rectangles_intersect(rect, furniture)
  })
}

pub fn avatar_rect(point: WorldPoint) -> ExclusionRect {
  let WorldPoint(x, y) = point
  let half_width = avatar_size / 2
  ExclusionRect(
    left: x - half_width,
    top: y - avatar_size,
    width: avatar_size,
    height: avatar_size,
  )
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
  let half_width = avatar_size / 2
  let height = avatar_size
  let safe_width = int.max(0, viewport_width)
  let safe_height = int.max(0, viewport_height)
  let avatar_left = anchor_x - half_width
  let avatar_top = anchor_y - height
  let avatar_right = anchor_x + half_width
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
    #("size", json.int(avatar_size)),
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

fn point_in_rect(point: WorldPoint, rect: ExclusionRect) -> Bool {
  let WorldPoint(x, y) = point
  let ExclusionRect(left, top, width, height) = rect

  x >= left && x < left + width && y >= top && y < top + height
}
