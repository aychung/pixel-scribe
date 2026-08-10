## Task 10: Define the pure office world, camera, and local avatar placement

**Description:** Create the renderer-independent logical office world, camera and
coordinate transforms, 50 curated anchors, participant reconciliation, avatar
variant selection, and stable draw ordering. The world is larger than the canvas,
and the current client's avatar is the camera target. Do not call Canvas or load
assets in this task.

### Work units

- [ ] **Task 10A — Define world metadata, coordinate types, and anchors.**
  - **Done when:** tile/world/avatar/bubble constants use named coordinate records
    and at least 50 curated anchors are unique, integral, in bounds, and outside
    declared furniture/edge exclusions.
  - **Files:** `src/pixel_scribe_frontend/scene.gleam`,
    `test/pixel_scribe_frontend/scene_test.gleam`.
  - **Verify:** failing metadata/anchor validation tests first, then all Gleam
    checks; inspect imports for browser/socket/view modules.
  - **Depends:** Tasks 5E and 7D.
- [ ] **Task 10B — Implement seeded placement and reconciliation.**
  - **Done when:** hash-plus-linear-probing allocation is deterministic, retains
    survivors, frees departures, ignores username/order for identity, fills 0-50
    unique anchors, and returns an explicit exhaustion result.
  - **Files:** `src/pixel_scribe_frontend/placement.gleam`,
    `test/pixel_scribe_frontend/scene_test.gleam`.
  - **Verify:** empty/full/shuffled/churn/duplicate-name/same-seed/different-seed/
    exhaustion tests plus all Gleam checks.
  - **Depends:** Task 10A.
- [ ] **Task 10C — Implement self-centered camera transforms.**
  - **Done when:** even viewport extents, unclamped origin, forward/inverse
    transforms, resize, missing self, reconnect target, and world-edge cases are
    pure; peer-only changes cannot change camera origin.
  - **Files:** `src/pixel_scribe_frontend/camera.gleam`,
    `test/pixel_scribe_frontend/camera_test.gleam`.
  - **Verify:** failing table tests for every named case, then all Gleam checks.
  - **Depends:** Task 10B.
- [ ] **Task 10D — Build stable renderer-independent draw data.**
  - **Done when:** avatar variant derives from the seed independently of anchor,
    draw passes are explicit, and avatars sort by bottom Y then connection ID with
    no Canvas/browser value in the output.
  - **Files:** `src/pixel_scribe_frontend/scene.gleam`,
    `test/pixel_scribe_frontend/scene_test.gleam`.
  - **Verify:** stable-order/variant/layer tests plus all Gleam checks.
  - **Depends:** Task 10C.

**Implementation notes:**

1. Define named constants: tile `16`, initial world `96 x 64` tiles
   (`1536 x 1024` logical pixels), avatar bottom-center and visual-center offsets,
   bubble limits, and distinct world/viewport/CSS/device coordinate records.
2. Define at least 50 walkable anchor points in the larger world. Validate at test
   time that anchors are in bounds, unique, and outside declared furniture/edge
   exclusion regions.
3. Reconcile by retaining placements for IDs present in the new set, releasing
   departed IDs, then allocating newcomers from seeded hash start plus linear
   probing. Never depend on username or list iteration order for identity.
4. Derive the camera target only from the avatar whose connection ID equals
   `self_id`. Round viewport width/height down to even logical dimensions, set
   camera origin to `self_visual_center - viewport_extent / 2`, and do not clamp
   at world edges. A target change recenters immediately; peer placement changes
   leave camera origin unchanged.
5. Derive avatar variant independently from placement seed, then build immutable
   world render data in stable passes and Y-sort avatars by bottom anchor with
   connection ID as deterministic tie-breaker.

**Acceptance criteria:**

- [ ] Sets from 0 through 50 unique connections receive unique, in-bounds,
  furniture-safe anchors; the same seed/input produces the same result.
- [ ] Snapshot/join/leave reconciliation retains survivors, frees departures,
  handles duplicate usernames, and never writes coordinates to protocol state.
- [ ] Camera/world-to-viewport transforms are pure and keep the self avatar at
  the exact viewport center after initial placement, self relocation, new
  reconnect `self_id`, resize, and world-edge placement; peer churn does not pan.

**Verification:**

- [ ] Property/table tests cover empty, full-50, shuffled input, churn, same name,
  same seed, different seed, and anchor exhaustion behavior.
- [ ] Camera tests cover even/odd canvas extents, self target changes, peer-only
  changes, viewport resize, world corners, inverse transforms, and missing self.
- [ ] `gleam format --check src test`
- [ ] `gleam build`
- [ ] `gleam test`
- [ ] Review module imports: no socket, Lustre view, FFI, or browser module.

**Dependencies:** Tasks 5 and 7.

**Files likely touched:**

- `src/pixel_scribe_frontend/scene.gleam`
- `src/pixel_scribe_frontend/placement.gleam`
- `src/pixel_scribe_frontend/camera.gleam`
- `test/pixel_scribe_frontend/scene_test.gleam`
- `test/pixel_scribe_frontend/camera_test.gleam`

**Estimated scope:** Medium, 5 files.

