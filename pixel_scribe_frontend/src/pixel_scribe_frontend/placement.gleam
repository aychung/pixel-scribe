import gleam/int
import gleam/list
import gleam/order
import gleam/string
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/scene

/// A local placement owned by one opaque WebSocket connection ID.
pub type Placement {
  Placement(connection_id: domain.ConnectionId, anchor: scene.Anchor)
}

pub type PlacementError {
  AnchorExhausted(connection_id: domain.ConnectionId)
}

/// Reconcile a presence snapshot or delta against local placements.
///
/// Existing valid placements are retained for still-present IDs. New IDs are
/// sorted by opaque connection ID before allocation, so usernames and server
/// list order cannot affect the result. Departed IDs are absent from the
/// returned list and therefore release their anchors.
pub fn reconcile(
  seed: Int,
  previous: List(Placement),
  participants: List(domain.Presence),
) -> Result(List(Placement), PlacementError) {
  let canonical_previous = canonical_previous(previous)
  let ordered_participants =
    participants
    |> unique_participants
    |> list.sort(by: compare_participants)

  let survivors =
    reserve_survivors(ordered_participants, canonical_previous, [])
  let newcomers =
    list.filter(ordered_participants, fn(participant) {
      !has_placement(participant.connection_id, survivors)
    })

  case allocate_newcomers(seed, newcomers, survivors) {
    Ok(placements) -> Ok(list.sort(placements, by: compare_placements))
    Error(error) -> Error(error)
  }
}

/// Look up one assigned anchor without exposing any username-based identity.
pub fn anchor_for(
  connection_id: domain.ConnectionId,
  placements: List(Placement),
) -> Result(scene.Anchor, Nil) {
  case
    list.find(placements, fn(placement) {
      placement.connection_id == connection_id
    })
  {
    Ok(placement) -> Ok(placement.anchor)
    Error(_) -> Error(Nil)
  }
}

fn reserve_survivors(
  participants: List(domain.Presence),
  previous: List(Placement),
  survivors: List(Placement),
) -> List(Placement) {
  case participants {
    [] -> survivors
    [participant, ..rest] ->
      case previous_placement(participant.connection_id, previous) {
        Ok(existing) ->
          case anchor_is_occupied(existing.anchor, survivors) {
            True -> reserve_survivors(rest, previous, survivors)
            False -> reserve_survivors(rest, previous, [existing, ..survivors])
          }
        Error(_) -> reserve_survivors(rest, previous, survivors)
      }
  }
}

fn allocate_newcomers(
  seed: Int,
  participants: List(domain.Presence),
  assigned: List(Placement),
) -> Result(List(Placement), PlacementError) {
  case participants {
    [] -> Ok(list.reverse(assigned))
    [participant, ..rest] -> {
      let connection_id = participant.connection_id

      case find_free_anchor(seed, connection_id, assigned, 0) {
        Ok(anchor) ->
          allocate_newcomers(seed, rest, [
            Placement(connection_id, anchor),
            ..assigned
          ])
        Error(_) -> Error(AnchorExhausted(connection_id))
      }
    }
  }
}

fn find_free_anchor(
  seed: Int,
  connection_id: domain.ConnectionId,
  assigned: List(Placement),
  probe: Int,
) -> Result(scene.Anchor, Nil) {
  let anchor_count = list.length(scene.curated_anchors)

  case probe >= anchor_count {
    True -> Error(Nil)
    False -> {
      let position =
        positive_mod(start_index(seed, connection_id) + probe, anchor_count)

      let assert [anchor, ..] = list.drop(scene.curated_anchors, position)

      case anchor_is_occupied(anchor, assigned) {
        True -> find_free_anchor(seed, connection_id, assigned, probe + 1)
        False -> Ok(anchor)
      }
    }
  }
}

fn start_index(seed: Int, connection_id: domain.ConnectionId) -> Int {
  let anchor_count = list.length(scene.curated_anchors)
  let initial = positive_mod(seed, anchor_count)

  domain.connection_id_to_string(connection_id)
  |> string.to_utf_codepoints
  |> list.fold(initial, fn(hash, codepoint) {
    positive_mod(
      hash * 31 + string.utf_codepoint_to_int(codepoint),
      anchor_count,
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

fn scene_anchor_by_id(index: Int) -> Result(scene.Anchor, Nil) {
  list.find(scene.curated_anchors, fn(anchor) { anchor.index == index })
}

fn anchor_is_occupied(anchor: scene.Anchor, assigned: List(Placement)) -> Bool {
  list.any(assigned, fn(placement) { placement.anchor.index == anchor.index })
}

fn previous_placement(
  connection_id: domain.ConnectionId,
  previous: List(Placement),
) -> Result(Placement, Nil) {
  list.find(previous, fn(placement) { placement.connection_id == connection_id })
}

fn has_placement(
  connection_id: domain.ConnectionId,
  placements: List(Placement),
) -> Bool {
  list.any(placements, fn(placement) {
    placement.connection_id == connection_id
  })
}

fn canonical_previous(previous: List(Placement)) -> List(Placement) {
  previous
  |> list.filter_map(fn(placement) {
    case scene_anchor_by_id(placement.anchor.index) {
      Ok(anchor) -> Ok(Placement(placement.connection_id, anchor))
      Error(_) -> Error(Nil)
    }
  })
  |> list.sort(by: compare_placements)
  |> unique_placements_by_id
}

fn unique_placements_by_id(placements: List(Placement)) -> List(Placement) {
  placements
  |> list.fold([], fn(seen: List(Placement), placement: Placement) {
    case
      list.any(seen, fn(existing) {
        existing.connection_id == placement.connection_id
      })
    {
      True -> seen
      False -> [placement, ..seen]
    }
  })
  |> list.reverse
}

fn unique_participants(
  participants: List(domain.Presence),
) -> List(domain.Presence) {
  participants
  |> list.fold(
    [],
    fn(seen: List(domain.Presence), participant: domain.Presence) {
      case
        list.any(seen, fn(existing) {
          existing.connection_id == participant.connection_id
        })
      {
        True -> seen
        False -> [participant, ..seen]
      }
    },
  )
  |> list.reverse
}

fn compare_participants(
  left: domain.Presence,
  right: domain.Presence,
) -> order.Order {
  string.compare(
    domain.connection_id_to_string(left.connection_id),
    domain.connection_id_to_string(right.connection_id),
  )
}

fn compare_placements(left: Placement, right: Placement) -> order.Order {
  case
    string.compare(
      domain.connection_id_to_string(left.connection_id),
      domain.connection_id_to_string(right.connection_id),
    )
  {
    order.Eq -> int.compare(left.anchor.index, right.anchor.index)
    order -> order
  }
}
