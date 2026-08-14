import pixel_scribe_frontend/camera
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/placement
import pixel_scribe_frontend/scene

pub fn camera_normalizes_even_odd_and_negative_viewport_extents_test() {
  let self = participant("self")
  let placements = assigned([self])
  let self_id = domain.connection_id_from_string("self")
  let assert Ok(even) = camera.new(100, 80, self_id, placements)
  let assert Ok(odd) = camera.new(101, 81, self_id, placements)
  let assert Ok(negative) = camera.new(-3, -5, self_id, placements)

  assert even.viewport == camera.ViewportExtent(width: 100, height: 80)
  assert odd.viewport == camera.ViewportExtent(width: 100, height: 80)
  assert negative.viewport == camera.ViewportExtent(width: 0, height: 0)
}

pub fn camera_centers_visual_self_without_clamping_test() {
  let self = participant("self")
  let placements = assigned([self])
  let self_id = domain.connection_id_from_string("self")
  let assert Ok(camera_state) = camera.new(100, 80, self_id, placements)
  let assert Ok(self_placement) = placement.anchor_for(self_id, placements)
  let visual_center = scene.avatar_visual_center(self_placement.position)

  assert camera_state.origin
    == scene.WorldPoint(visual_center.x - 50, visual_center.y - 40)
  assert camera.world_to_viewport(camera_state, visual_center)
    == scene.ViewportPoint(x: 50, y: 40)
  assert camera.viewport_to_world(camera_state, scene.ViewportPoint(50, 40))
    == visual_center
}

pub fn camera_keeps_unclamped_negative_origin_at_world_edge_test() {
  let placements = [
    placement.Placement(
      domain.connection_id_from_string("self"),
      scene.Anchor(0, scene.WorldPoint(128, 128)),
    ),
  ]
  let self_id = domain.connection_id_from_string("self")
  let assert Ok(camera_state) = camera.new(640, 480, self_id, placements)

  assert camera_state.origin == scene.WorldPoint(-192, -120)
}

pub fn camera_keeps_unclamped_positive_world_overflow_at_far_edge_test() {
  let placements = [
    placement.Placement(
      domain.connection_id_from_string("self"),
      scene.Anchor(49, scene.WorldPoint(1424, 832)),
    ),
  ]
  let self_id = domain.connection_id_from_string("self")
  let assert Ok(camera_state) = camera.new(640, 480, self_id, placements)

  assert camera_state.origin == scene.WorldPoint(1104, 584)
}

pub fn camera_centers_literal_logical_world_corners_without_clamping_test() {
  let self_id = domain.connection_id_from_string("self")
  let top_left = [
    placement.Placement(self_id, scene.Anchor(0, scene.WorldPoint(0, 0))),
  ]
  let bottom_right = [
    placement.Placement(
      self_id,
      scene.Anchor(
        1,
        scene.WorldPoint(
          scene.world_pixel_width - 1,
          scene.world_pixel_height - 1,
        ),
      ),
    ),
  ]
  let assert Ok(top_left_camera) = camera.new(640, 480, self_id, top_left)
  let assert Ok(bottom_right_camera) =
    camera.new(640, 480, self_id, bottom_right)
  let top_left_center = scene.avatar_visual_center(scene.WorldPoint(0, 0))
  let bottom_right_center =
    scene.avatar_visual_center(scene.WorldPoint(
      scene.world_pixel_width - 1,
      scene.world_pixel_height - 1,
    ))

  assert top_left_camera.origin == scene.WorldPoint(-320, -248)
  assert bottom_right_camera.origin == scene.WorldPoint(1215, 775)
  assert camera.world_to_viewport(top_left_camera, top_left_center)
    == scene.ViewportPoint(x: 320, y: 240)
  assert camera.world_to_viewport(bottom_right_camera, bottom_right_center)
    == scene.ViewportPoint(x: 320, y: 240)
}

pub fn camera_resize_recenters_the_same_self_target_test() {
  let self = participant("self")
  let placements = assigned([self])
  let self_id = domain.connection_id_from_string("self")
  let assert Ok(initial) = camera.new(100, 80, self_id, placements)
  let assert Ok(resized) = camera.resize(initial, 111, 91, placements)
  let assert Ok(self_placement) = placement.anchor_for(self_id, placements)
  let visual_center = scene.avatar_visual_center(self_placement.position)

  assert resized.viewport == camera.ViewportExtent(width: 110, height: 90)
  assert camera.world_to_viewport(resized, visual_center)
    == scene.ViewportPoint(x: 55, y: 45)
}

pub fn camera_retarget_and_reconnect_self_id_immediately_recenters_test() {
  let self = participant("self")
  let peer = participant("peer")
  let placements = assigned([self, peer])
  let self_id = domain.connection_id_from_string("self")
  let peer_id = domain.connection_id_from_string("peer")
  let assert Ok(initial) = camera.new(100, 80, self_id, placements)
  let assert Ok(retargeted) = camera.retarget(initial, peer_id, placements)
  let assert Ok(peer_placement) = placement.anchor_for(peer_id, placements)
  let peer_center = scene.avatar_visual_center(peer_placement.position)

  assert retargeted.self_id == peer_id
  assert camera.world_to_viewport(retargeted, peer_center)
    == scene.ViewportPoint(x: 50, y: 40)
  assert retargeted.origin != initial.origin
}

pub fn camera_peer_only_changes_leave_origin_unchanged_test() {
  let self = participant("self")
  let peer = participant("peer")
  let replacement = participant("replacement")
  let self_id = domain.connection_id_from_string("self")
  let first = assigned([self, peer])
  let second = assigned([self, replacement])
  let assert Ok(initial) = camera.new(100, 80, self_id, first)
  let assert Ok(updated) = camera.update(initial, second)

  assert updated.origin == initial.origin
  assert updated.self_id == self_id
}

pub fn camera_update_recenters_after_same_self_relocation_test() {
  let self_id = domain.connection_id_from_string("self")
  let initial_placements = [
    placement.Placement(self_id, scene.Anchor(0, scene.WorldPoint(0, 0))),
  ]
  let relocated_placements = [
    placement.Placement(self_id, scene.Anchor(49, scene.WorldPoint(1424, 832))),
  ]
  let assert Ok(initial) = camera.new(640, 480, self_id, initial_placements)
  let assert Ok(relocated) = camera.update(initial, relocated_placements)
  let relocated_center = scene.avatar_visual_center(scene.WorldPoint(1424, 832))

  assert relocated.origin != initial.origin
  assert camera.world_to_viewport(relocated, relocated_center)
    == scene.ViewportPoint(x: 320, y: 240)
}

pub fn camera_peer_anchor_and_list_order_changes_do_not_pan_self_test() {
  let self_id = domain.connection_id_from_string("self")
  let peer_id = domain.connection_id_from_string("peer")
  let initial_placements = [
    placement.Placement(self_id, scene.Anchor(0, scene.WorldPoint(128, 128))),
    placement.Placement(peer_id, scene.Anchor(1, scene.WorldPoint(272, 128))),
  ]
  let changed_peer_placements = [
    placement.Placement(peer_id, scene.Anchor(49, scene.WorldPoint(1424, 832))),
    placement.Placement(self_id, scene.Anchor(0, scene.WorldPoint(128, 128))),
  ]
  let assert Ok(initial) = camera.new(640, 480, self_id, initial_placements)
  let assert Ok(updated) = camera.update(initial, changed_peer_placements)

  assert updated.origin == initial.origin
}

pub fn camera_reports_missing_self_explicitly_test() {
  let placements = assigned([participant("peer")])
  let missing_id = domain.connection_id_from_string("missing")

  assert camera.new(100, 80, missing_id, placements)
    == Error(camera.MissingSelf)
}

pub fn camera_forward_and_inverse_transforms_round_trip_negative_origin_test() {
  let placements = [
    placement.Placement(
      domain.connection_id_from_string("self"),
      scene.Anchor(0, scene.WorldPoint(128, 128)),
    ),
  ]
  let self_id = domain.connection_id_from_string("self")
  let assert Ok(camera_state) = camera.new(640, 480, self_id, placements)
  let world = scene.WorldPoint(-17, 29)
  let viewport = camera.world_to_viewport(camera_state, world)

  assert camera.viewport_to_world(camera_state, viewport) == world
}

fn participant(id: String) -> domain.Presence {
  domain.Presence(domain.connection_id_from_string(id), id)
}

fn assigned(participants: List(domain.Presence)) -> List(placement.Placement) {
  let assert Ok(placements) = placement.reconcile(17, [], participants)
  placements
}
