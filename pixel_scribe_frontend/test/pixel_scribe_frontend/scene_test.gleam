import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/model
import pixel_scribe_frontend/placement
import pixel_scribe_frontend/scene
import pixel_scribe_frontend/update

pub fn world_metadata_has_named_logical_extents_test() {
  assert scene.tile_size == 16
  assert scene.world_tile_extent == scene.TileExtent(width: 21, height: 11)
  assert scene.world_pixel_extent == scene.WorldExtent(width: 336, height: 176)
  assert scene.avatar_bottom_center_offset == scene.WorldOffset(dx: 0, dy: 0)
  assert scene.avatar_visual_center_offset == scene.WorldOffset(dx: 0, dy: -8)
  assert scene.bubble_limits.max_width == 160
  assert scene.bubble_limits.max_lines == 3
}

pub fn curated_anchors_are_unique_integral_and_walkable_test() {
  let anchors = scene.curated_anchors

  assert list.length(anchors) >= 50
  assert list.all(anchors, fn(anchor) {
    scene.world_point_is_in_bounds(anchor.position)
    && !list.any(scene.edge_exclusions, fn(exclusion) {
      scene.point_is_in_exclusion(anchor.position, exclusion)
    })
  })
  assert list.all(anchors, fn(anchor) {
    scene.anchor_is_walkable(anchor.position)
  })
  assert list.all(anchors, fn(anchor) {
    anchor.position.x % scene.tile_size == 8
    && anchor.position.y % scene.tile_size == 0
  })
  assert unique_indices(anchors) == list.length(anchors)
  assert unique_positions(anchors) == list.length(anchors)
}

pub fn compact_avatar_rectangles_do_not_hit_room_geometry_or_each_other_test() {
  assert list.all(scene.curated_anchors, fn(left) {
    let left_rect = scene.avatar_rect(left.position)
    !list.any(scene.edge_exclusions, fn(wall) {
      scene.rectangles_intersect(left_rect, wall)
    })
    && !list.any(scene.furniture_exclusions, fn(furniture) {
      scene.rectangles_intersect(left_rect, furniture)
    })
    && !list.any(scene.curated_anchors, fn(right) {
      left.index != right.index
      && scene.rectangles_intersect(
        left_rect,
        scene.avatar_rect(right.position),
      )
    })
  })
  assert list.all(scene.curated_anchors, scene.anchor_has_clear_footprint)
}

pub fn wall_decor_and_rugs_are_walkable_backdrops_test() {
  // The renderer draws these assets before avatars; they are decorative
  // surfaces rather than blocking furniture.
  assert scene.anchor_is_walkable(scene.WorldPoint(24, 32))
  assert scene.anchor_is_walkable(scene.WorldPoint(184, 128))
}

pub fn compact_office_has_a_doorway_between_two_rooms_test() {
  assert scene.world_tile_extent == scene.TileExtent(width: 21, height: 11)
  assert scene.anchor_is_walkable(scene.WorldPoint(168, 80))
  assert !scene.anchor_is_walkable(scene.WorldPoint(168, 32))
  assert !scene.anchor_is_walkable(scene.WorldPoint(168, 144))
  assert scene.anchor_is_walkable(scene.WorldPoint(312, 144))
}

pub fn coordinate_spaces_are_distinct_records_test() {
  let world = scene.WorldPoint(x: 320, y: 208)
  let viewport = scene.ViewportPoint(x: 12, y: 16)
  let css = scene.CssPoint(x: 12, y: 16)
  let device = scene.DevicePoint(x: 24, y: 32)

  assert world.x == 320
  assert viewport.y == 16
  assert css.x == 12
  assert device.y == 32
}

pub fn renderer_passes_are_explicit_and_stably_ordered_test() {
  assert scene.draw_passes
    == [
      scene.StaticFloorWalls,
      scene.Furniture,
      scene.Avatars,
      scene.NameSelfStatusAccents,
      scene.SpeechBubbles,
    ]
}

pub fn avatar_variant_is_seeded_by_opaque_id_not_anchor_or_username_test() {
  let connection_id = domain.connection_id_from_string("connection-a")
  let first =
    scene.AvatarInput(
      connection_id: connection_id,
      username: "Ada",
      bottom_anchor: scene.WorldPoint(128, 128),
      status: scene.Online,
    )
  let moved_and_renamed =
    scene.AvatarInput(
      connection_id: connection_id,
      username: "Different label",
      bottom_anchor: scene.WorldPoint(1424, 832),
      status: scene.Reconnecting,
    )
  let first_data = scene.render_data(17, connection_id, [first])
  let moved_data = scene.render_data(17, connection_id, [moved_and_renamed])
  let assert [first_draw] = first_data.avatars
  let assert [moved_draw] = moved_data.avatars

  assert scene.avatar_variant(17, connection_id)
    == scene.avatar_variant(17, connection_id)
  assert scene.avatar_variant(17, connection_id)
    != scene.avatar_variant(18, connection_id)
  assert first_draw.variant == moved_draw.variant
  assert first_draw.bottom_anchor != moved_draw.bottom_anchor
}

pub fn avatar_variant_uses_the_full_atlas_domain_test() {
  let connection_id = domain.connection_id_from_string("connection-a")

  assert scene.avatar_variant(17, connection_id) == scene.AvatarVariant(28)
}

pub fn renderer_avatars_sort_by_bottom_y_then_connection_id_test() {
  let self_id = domain.connection_id_from_string("b")
  let avatars = [
    avatar_input("z", "Zed", 300),
    avatar_input("a", "Ada", 200),
    avatar_input("b", "Bea", 300),
  ]
  let permuted_avatars = [
    avatar_input("b", "Bea", 300),
    avatar_input("z", "Zed", 300),
    avatar_input("a", "Ada", 200),
  ]
  let data = scene.render_data(17, self_id, avatars)
  let permuted_data = scene.render_data(17, self_id, permuted_avatars)

  let assert [first, second, third] = data.avatars
  assert first.connection_id == domain.connection_id_from_string("a")
  assert second.connection_id == domain.connection_id_from_string("b")
  assert third.connection_id == domain.connection_id_from_string("z")
  assert second.is_self
  assert first.is_self == False
  assert data.avatars == permuted_data.avatars
}

pub fn live_bubbles_are_owned_replaced_and_cleared_by_connection_id_test() {
  let self_id = domain.connection_id_from_string("self")
  let peer_id = domain.connection_id_from_string("peer")
  let data =
    scene.render_data(17, self_id, [
      avatar_input("self", "Ada", 128),
      avatar_input("peer", "Bea", 304),
    ])
  let first = chat_message("first", peer_id, "hello")
  let replacement = chat_message("second", peer_id, "new hello")

  let with_first = scene.add_bubble(data, first, 1000)
  assert with_first.bubbles
    == [
      scene.Bubble(first.message_id, first.sender_id, first.text, 1000, 7000),
    ]

  let with_replacement = scene.add_bubble(with_first, replacement, 2000)
  assert with_replacement.bubbles
    == [
      scene.Bubble(
        replacement.message_id,
        replacement.sender_id,
        replacement.text,
        2000,
        8000,
      ),
    ]

  let survivor_data =
    scene.render_data(17, self_id, [avatar_input("self", "Ada", 128)])
  let cleared =
    scene.retain_bubbles(with_replacement, survivor_data, [
      domain.Presence(self_id, "Ada"),
    ])
  assert cleared.bubbles == []
}

pub fn duplicate_or_unknown_sender_bubbles_do_nothing_test() {
  let self_id = domain.connection_id_from_string("self")
  let peer_id = domain.connection_id_from_string("peer")
  let absent_id = domain.connection_id_from_string("absent")
  let data =
    scene.render_data(17, self_id, [
      avatar_input("self", "Ada", 128),
      avatar_input("peer", "Bea", 304),
    ])
  let first = chat_message("same-id", peer_id, "hello")
  let duplicate = chat_message("same-id", self_id, "different owner")
  let unknown = chat_message("unknown", absent_id, "not present")

  let with_first = scene.add_bubble(data, first, 1000)
  assert scene.add_bubble(with_first, duplicate, 2000) == with_first
  assert scene.add_bubble(with_first, unknown, 2000) == with_first
}

pub fn room_snapshot_history_never_creates_bubbles_test() {
  let self_id = domain.connection_id_from_string("snapshot-self")
  let peer_id = domain.connection_id_from_string("snapshot-peer")
  let awaiting =
    model.Model(
      ..model.initial(),
      phase: model.AwaitingRoomState(41, 0),
      socket_generation: 41,
    )
  let history = chat_message("history", peer_id, "old message")
  let peer = domain.Presence(peer_id, "Bea")
  let self_presence = domain.Presence(self_id, "Ada")

  let #(joined, _) =
    update.transition(
      awaiting,
      update.ServerEvent(
        41,
        0,
        domain.RoomState(
          domain.default_room_id,
          self_id,
          [self_presence, peer],
          [history],
        ),
      ),
    )

  let assert model.Ready(_, _, _, render_data, _, _) = joined.scene
  assert render_data.bubbles == []
}

pub fn accepted_live_message_creates_duplicate_safe_bubble_and_leave_clears_test() {
  let self_id = domain.connection_id_from_string("live-self")
  let peer_id = domain.connection_id_from_string("live-peer")
  let peer = domain.Presence(peer_id, "Bea")
  let self_presence = domain.Presence(self_id, "Ada")
  let awaiting =
    model.Model(
      ..model.initial(),
      phase: model.AwaitingRoomState(42, 0),
      socket_generation: 42,
    )
  let #(joined, _) =
    update.transition(
      awaiting,
      update.ServerEvent(
        42,
        0,
        domain.RoomState(
          domain.default_room_id,
          self_id,
          [self_presence, peer],
          [],
        ),
      ),
    )
  let accepted = chat_message("live", peer_id, "live message")
  let #(with_bubble, _) =
    update.transition(
      joined,
      update.AcceptedMessage(42, 0, domain.default_room_id, accepted, False),
    )
  let assert model.Ready(_, _, _, with_data, _, _) = with_bubble.scene
  assert with_data.bubbles
    == [
      scene.Bubble(
        accepted.message_id,
        accepted.sender_id,
        accepted.text,
        0,
        scene.bubble_lifetime_ms,
      ),
    ]

  let assert #(duplicate, []) =
    update.transition(
      with_bubble,
      update.AcceptedMessage(42, 0, domain.default_room_id, accepted, False),
    )
  assert duplicate == with_bubble

  let assert #(left, [update.CancelBubble(42, 1)]) =
    update.transition(
      with_bubble,
      update.ServerEvent(
        42,
        0,
        domain.UserLeft(domain.default_room_id, peer_id),
      ),
    )
  let assert model.Ready(_, _, _, left_data, _, _) = left.scene
  assert left_data.bubbles == []
}

pub fn bubble_layout_splits_explicit_lines_before_wrapping_and_preserves_text_test() {
  let sender_id = domain.connection_id_from_string("bubble-lines")
  let data =
    scene.render_data(17, sender_id, [avatar_input("bubble-lines", "Ada", 128)])
  let message = chat_message("lines", sender_id, "first line\nsecond line")
  let assert [bubble] = scene.add_bubble(data, message, 0).bubbles

  let layout =
    scene.layout_bubble(bubble, scene.ViewportPoint(x: 80, y: 80), 200, 120)

  assert layout.lines == ["first line", "second line"]
  assert layout.truncated == False
  assert bubble.text == "first line\nsecond line"
}

pub fn bubble_layout_caps_visual_lines_and_uses_ellipsis_only_when_truncated_test() {
  let sender_id = domain.connection_id_from_string("bubble-truncate")
  let data =
    scene.render_data(17, sender_id, [
      avatar_input("bubble-truncate", "Ada", 128),
    ])
  let message =
    chat_message(
      "truncate",
      sender_id,
      "one two three four five six seven eight nine ten eleven twelve thirteen",
    )
  let assert [bubble] = scene.add_bubble(data, message, 0).bubbles

  let layout =
    scene.layout_bubble(bubble, scene.ViewportPoint(x: 80, y: 80), 200, 120)

  assert list.length(layout.lines) == scene.bubble_limits.max_lines
  assert layout.truncated
  let assert Ok(last_line) = list.last(layout.lines)
  assert string.ends_with(last_line, "...")
  assert bubble.text == message.text

  let short =
    scene.layout_bubble(
      scene.Bubble(
        message.message_id,
        message.sender_id,
        "short",
        0,
        scene.bubble_lifetime_ms,
      ),
      scene.ViewportPoint(x: 80, y: 80),
      200,
      120,
    )
  assert short.truncated == False
  assert list.all(short.lines, fn(line) { !string.ends_with(line, "...") })
}

pub fn bubble_layout_is_emoji_safe_and_clamped_to_every_viewport_edge_test() {
  let sender_id = domain.connection_id_from_string("bubble-emoji")
  let data =
    scene.render_data(17, sender_id, [avatar_input("bubble-emoji", "Ada", 128)])
  let emoji_text = string.repeat("🙂", 50)
  let message = chat_message("emoji", sender_id, emoji_text)
  let assert [bubble] = scene.add_bubble(data, message, 0).bubbles

  let left =
    scene.layout_bubble(bubble, scene.ViewportPoint(x: 0, y: 0), 200, 120)
  let right =
    scene.layout_bubble(bubble, scene.ViewportPoint(x: 200, y: 120), 200, 120)

  assert list.length(left.lines) <= scene.bubble_limits.max_lines
  assert list.all(left.lines, fn(line) { string.length(line) <= 10 })
  assert list.any(left.lines, fn(line) { string.ends_with(line, "...") })
  assert left.rectangle.left >= 0
  assert left.rectangle.top >= 0
  assert left.rectangle.left + left.rectangle.width <= 200
  assert left.rectangle.top + left.rectangle.height <= 120
  assert right.rectangle.left >= 0
  assert right.rectangle.top >= 0
  assert right.rectangle.left + right.rectangle.width <= 200
  assert right.rectangle.top + right.rectangle.height <= 120
  assert bubble.text == emoji_text
}

pub fn bubble_layout_prices_zwj_family_as_one_grapheme_test() {
  let sender_id = domain.connection_id_from_string("bubble-family")
  let data =
    scene.render_data(17, sender_id, [avatar_input("bubble-family", "Ada", 128)])
  let family = "👨‍👩‍👧‍👦"
  let family_text = string.repeat(family, 18)
  let message = chat_message("family", sender_id, family_text)
  let assert [bubble] = scene.add_bubble(data, message, 0).bubbles

  let layout =
    scene.layout_bubble(bubble, scene.ViewportPoint(x: 80, y: 80), 200, 120)

  assert layout.lines == [string.repeat(family, 9), string.repeat(family, 9)]
  assert layout.truncated == False
}

pub fn bubble_layout_prices_decomposed_combining_grapheme_not_codepoints_test() {
  let sender_id = domain.connection_id_from_string("bubble-combining")
  let data =
    scene.render_data(17, sender_id, [
      avatar_input("bubble-combining", "Ada", 128),
    ])
  let combining = "e\u{301}\u{308}"
  let combining_text = string.repeat(combining, 12)
  let message = chat_message("combining", sender_id, combining_text)
  let assert [bubble] = scene.add_bubble(data, message, 0).bubbles

  let layout =
    scene.layout_bubble(bubble, scene.ViewportPoint(x: 80, y: 80), 200, 120)

  assert layout.lines
    == [string.repeat(combining, 9), string.repeat(combining, 3)]
  assert layout.truncated == False
}

pub fn bubble_lifecycle_is_visible_then_fades_then_expires_at_fixed_clock_test() {
  let sender_id = domain.connection_id_from_string("bubble-clock")
  let data =
    scene.render_data(17, sender_id, [avatar_input("bubble-clock", "Ada", 128)])
  let message = chat_message("clock", sender_id, "hello")
  let assert [bubble] = scene.add_bubble(data, message, 10_000).bubbles

  assert scene.bubble_visibility(bubble, 10_000, False) == scene.FullyVisible
  assert scene.bubble_visibility(bubble, 14_999, False) == scene.FullyVisible
  assert scene.bubble_visibility(bubble, 15_000, False) == scene.Fading(100)
  assert scene.bubble_visibility(bubble, 15_500, False) == scene.Fading(50)
  assert scene.bubble_visibility(bubble, 15_999, False) == scene.Fading(1)
  assert scene.bubble_visibility(bubble, 16_000, False) == scene.Expired
}

pub fn bubble_lifecycle_reduced_motion_keeps_full_opacity_until_expiry_test() {
  let sender_id = domain.connection_id_from_string("bubble-reduced")
  let data =
    scene.render_data(17, sender_id, [
      avatar_input("bubble-reduced", "Ada", 128),
    ])
  let message = chat_message("reduced", sender_id, "hello")
  let assert [bubble] = scene.add_bubble(data, message, 10_000).bubbles

  assert scene.bubble_visibility(bubble, 15_999, True) == scene.FullyVisible
  assert scene.bubble_visibility(bubble, 16_000, True) == scene.Expired
}

pub fn bubble_lifecycle_schedules_only_the_next_boundary_and_expiry_removes_it_test() {
  let sender_id = domain.connection_id_from_string("bubble-deadline")
  let data =
    scene.render_data(17, sender_id, [
      avatar_input("bubble-deadline", "Ada", 128),
    ])
  let message = chat_message("deadline", sender_id, "hello")
  let assert [bubble] = scene.add_bubble(data, message, 10_000).bubbles
  let with_bubble = scene.SceneRenderData(data.passes, data.avatars, [bubble])

  assert scene.next_bubble_boundary(with_bubble, 10_001, False)
    == Some(scene.BubbleDeadline(message.message_id, 15_000))
  assert scene.next_bubble_boundary(with_bubble, 15_100, False)
    == Some(scene.BubbleDeadline(message.message_id, 16_000))
  assert scene.next_bubble_boundary(with_bubble, 15_100, True)
    == Some(scene.BubbleDeadline(message.message_id, 16_000))
  assert scene.next_bubble_boundary(with_bubble, 16_000, False) == None
  assert scene.expire_bubbles(with_bubble, 15_999, False).bubbles == [bubble]
  assert scene.expire_bubbles(with_bubble, 16_000, False).bubbles == []
}

pub fn replacing_a_bubble_makes_the_old_identity_ineligible_for_expiry_test() {
  let sender_id = domain.connection_id_from_string("bubble-replace-clock")
  let data =
    scene.render_data(17, sender_id, [
      avatar_input("bubble-replace-clock", "Ada", 128),
    ])
  let first = chat_message("old", sender_id, "old")
  let replacement = chat_message("new", sender_id, "new")
  let replaced =
    scene.add_bubble(scene.add_bubble(data, first, 10_000), replacement, 12_000)

  assert scene.expire_bubbles(replaced, 16_000, False).bubbles
    == replaced.bubbles
  assert scene.next_bubble_boundary(replaced, 16_000, False)
    == Some(scene.BubbleDeadline(replacement.message_id, 17_000))
}

pub fn renderer_json_uses_canonical_bubble_lines_and_preserves_full_text_test() {
  let sender_id = domain.connection_id_from_string("bubble-json")
  let data =
    scene.render_data(17, sender_id, [avatar_input("bubble-json", "Ada", 128)])
  let message = chat_message("json", sender_id, "first line\nsecond line")
  let with_bubble = scene.add_bubble(data, message, 10_000)
  let assert [bubble] = with_bubble.bubbles
  let rendered =
    scene.render_data_json_for_viewport(with_bubble, 0, 0, 200, 120)

  assert with_bubble.bubbles == [bubble]
  assert string.contains(rendered, "\"lines\":[\"first line\",\"second line\"]")
  assert !string.contains(rendered, "\"text\"")
  assert string.contains(rendered, "\"left\":")
  assert string.contains(rendered, "\"expires_at_ms\":16000")
  assert string.contains(rendered, "\"size\":16")
}

pub fn renderer_json_omits_fully_offscreen_bubbles_but_keeps_visible_edge_owners_test() {
  let sender_id = domain.connection_id_from_string("bubble-offscreen")
  let message = chat_message("offscreen", sender_id, "hello")
  let offscreen_data =
    scene.render_data(17, sender_id, [
      scene.AvatarInput(
        connection_id: sender_id,
        username: "Ada",
        bottom_anchor: scene.WorldPoint(x: 128, y: 500),
        status: scene.Online,
      ),
    ])
    |> scene.add_bubble(message, 0)
  let offscreen_json =
    scene.render_data_json_for_viewport(offscreen_data, 0, 0, 320, 240)

  assert offscreen_data.bubbles != []
  assert string.contains(offscreen_json, "\"bubbles\":[]")

  let edge_data =
    scene.render_data(17, sender_id, [
      scene.AvatarInput(
        connection_id: sender_id,
        username: "Ada",
        bottom_anchor: scene.WorldPoint(x: 4, y: 16),
        status: scene.Online,
      ),
    ])
    |> scene.add_bubble(message, 0)
  let edge_json = scene.render_data_json_for_viewport(edge_data, 0, 0, 320, 240)

  assert string.contains(edge_json, "\"id\":\"offscreen\"")
  assert string.contains(edge_json, "\"left\":0")
}

fn chat_message(
  message_id: String,
  sender_id: domain.ConnectionId,
  text: String,
) -> domain.ChatMessage {
  domain.ChatMessage(
    domain.message_id_from_string(message_id),
    sender_id,
    "Sender",
    text,
    "2026-08-10T12:00:00Z",
  )
}

fn avatar_input(
  connection_id: String,
  username: String,
  y: Int,
) -> scene.AvatarInput {
  scene.AvatarInput(
    connection_id: domain.connection_id_from_string(connection_id),
    username: username,
    bottom_anchor: scene.WorldPoint(128, y),
    status: scene.Online,
  )
}

fn unique_positions(anchors: List(scene.Anchor)) -> Int {
  anchors
  |> list.fold([], fn(seen, anchor) {
    case list.contains(seen, anchor.position) {
      True -> seen
      False -> [anchor.position, ..seen]
    }
  })
  |> list.length
}

fn unique_indices(anchors: List(scene.Anchor)) -> Int {
  anchors
  |> list.fold([], fn(seen, anchor) {
    case list.contains(seen, anchor.index) {
      True -> seen
      False -> [anchor.index, ..seen]
    }
  })
  |> list.length
}

pub fn placement_reconciliation_handles_empty_and_every_capacity_test() {
  assert placement.reconcile(17, [], []) == Ok([])
  assert_capacity(0)
}

pub fn placement_reconciliation_is_seeded_and_order_independent_test() {
  let input = participants(12)
  let reversed = list.reverse(input)
  let assert Ok(first) = placement.reconcile(17, [], input)
  let assert Ok(same) = placement.reconcile(17, [], input)
  let assert Ok(shuffled) = placement.reconcile(17, [], reversed)
  let assert Ok(different_seed) = placement.reconcile(18, [], input)

  assert first == same
  assert first == shuffled
  assert first != different_seed
}

pub fn placement_reconciliation_retains_survivors_and_frees_departures_test() {
  let initial = [participant(0), participant(1), participant(2)]
  let next = [participant(1), participant(2), participant(3)]
  let assert Ok(before) = placement.reconcile(17, [], initial)
  let assert Ok(after) = placement.reconcile(17, before, next)

  let id_0 = domain.connection_id_from_string("connection-0")
  let id_1 = domain.connection_id_from_string("connection-1")
  let id_2 = domain.connection_id_from_string("connection-2")
  let id_3 = domain.connection_id_from_string("connection-3")

  assert placement.anchor_for(id_0, after) == Error(Nil)
  assert placement.anchor_for(id_1, before) == placement.anchor_for(id_1, after)
  assert placement.anchor_for(id_2, before) == placement.anchor_for(id_2, after)
  assert placement.anchor_for(id_3, after) != Error(Nil)
  assert unique_placement_anchors(after) == list.length(after)

  let all_participants = participants(50)
  let assert Ok(full) = placement.reconcile(17, [], all_participants)
  let without_departure =
    list.filter(all_participants, fn(participant) {
      participant.connection_id != id_0
    })
  let assert Ok(refilled) =
    placement.reconcile(17, full, [participant(50), ..without_departure])
  assert list.length(refilled) == 50
  assert unique_placement_anchors(refilled) == 50
}

pub fn placement_reserves_survivors_before_lower_sorting_newcomers_test() {
  let survivor = participant_with_id("z", "Survivor")
  let newcomer = participant_with_id("a7", "Newcomer")
  let survivor_id = domain.connection_id_from_string("z")

  let assert Ok(before) = placement.reconcile(17, [], [survivor])
  let assert Ok(after) = placement.reconcile(17, before, [newcomer, survivor])

  assert placement.anchor_for(survivor_id, before)
    == placement.anchor_for(survivor_id, after)
  assert unique_placement_anchors(after) == 2
}

pub fn placement_bounds_long_opaque_ids_during_hashing_test() {
  let long_id = "connection-" <> string.repeat("x9", 5000)
  let participant = participant_with_id(long_id, "Long ID")
  let assert Ok(first) = placement.reconcile(17, [], [participant])
  let assert Ok(second) = placement.reconcile(17, [], [participant])

  assert first == second
  assert list.length(first) == 1
  assert list.all(first, fn(item) {
    scene.anchor_is_walkable(item.anchor.position)
  })
}

pub fn placement_uses_connection_ids_not_duplicate_usernames_test() {
  let duplicate_name = [
    domain.Presence(
      domain.connection_id_from_string("connection-a"),
      "Same name",
    ),
    domain.Presence(
      domain.connection_id_from_string("connection-b"),
      "Same name",
    ),
    domain.Presence(
      domain.connection_id_from_string("connection-a"),
      "Renamed duplicate input",
    ),
  ]
  let assert Ok(assigned) = placement.reconcile(17, [], duplicate_name)

  assert list.length(assigned) == 2
  assert unique_placement_ids(assigned) == 2
  assert unique_placement_anchors(assigned) == 2
}

pub fn placement_returns_explicit_exhaustion_for_the_51st_connection_test() {
  let assert Error(error) = placement.reconcile(17, [], participants(51))

  let is_exhaustion = case error {
    placement.AnchorExhausted(_) -> True
  }
  assert is_exhaustion
}

fn assert_capacity(count: Int) {
  let assert Ok(assigned) = placement.reconcile(17, [], participants(count))
  assert list.length(assigned) == count
  assert unique_placement_ids(assigned) == count
  assert unique_placement_anchors(assigned) == count

  case count < 50 {
    True -> assert_capacity(count + 1)
    False -> Nil
  }
}

fn participants(count: Int) -> List(domain.Presence) {
  case count {
    0 -> []
    _ -> [participant(count - 1), ..participants(count - 1)]
  }
}

fn participant(index: Int) -> domain.Presence {
  participant_with_id("connection-" <> int.to_string(index), "Same name")
}

fn participant_with_id(id: String, username: String) -> domain.Presence {
  domain.Presence(domain.connection_id_from_string(id), username)
}

fn unique_placement_ids(placements: List(placement.Placement)) -> Int {
  placements
  |> list.fold([], fn(seen, item) {
    case list.contains(seen, item.connection_id) {
      True -> seen
      False -> [item.connection_id, ..seen]
    }
  })
  |> list.length
}

fn unique_placement_anchors(placements: List(placement.Placement)) -> Int {
  placements
  |> list.fold([], fn(seen, item) {
    case list.contains(seen, item.anchor.index) {
      True -> seen
      False -> [item.anchor.index, ..seen]
    }
  })
  |> list.length
}
