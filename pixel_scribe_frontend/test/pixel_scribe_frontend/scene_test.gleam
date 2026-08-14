import gleam/int
import gleam/list
import gleam/string
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/placement
import pixel_scribe_frontend/scene

pub fn world_metadata_has_named_logical_extents_test() {
  assert scene.tile_size == 16
  assert scene.world_tile_extent == scene.TileExtent(width: 96, height: 64)
  assert scene.world_pixel_extent
    == scene.WorldExtent(width: 1536, height: 1024)
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
    && !list.any(scene.furniture_exclusions, fn(exclusion) {
      scene.point_is_in_exclusion(anchor.position, exclusion)
    })
  })
  assert list.all(anchors, fn(anchor) {
    scene.anchor_is_walkable(anchor.position)
  })
  assert list.all(anchors, fn(anchor) {
    anchor.position.x % scene.tile_size == 0
    && anchor.position.y % scene.tile_size == 0
  })
  assert unique_indices(anchors) == list.length(anchors)
  assert unique_positions(anchors) == list.length(anchors)
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
