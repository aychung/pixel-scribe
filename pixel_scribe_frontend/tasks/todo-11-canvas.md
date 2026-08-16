## Task 11: Deliver the DPR-aware Canvas 2D renderer and approved assets

**Description:** Implement the narrow Canvas effect/FFI, resize and DPR handling,
asset cache/fallback, dirty frame scheduling, and layered scene rendering. Produce
an original or explicitly licensed top-down office/avatar baseline for review.

### Work units

- [x] **Task 11A — Establish original/licensed assets and provenance.**
  - **Done when:** the source tile/avatar assets have creator, source, license,
    modifications, tile size, and distribution permission recorded; no Pixel
    Agents artwork is copied without an asset-specific compatible license.
  - **Files:** `assets/pixel-art/` and `assets/pixel-art/README.md`.
  - **Verify:** inspect every asset against the provenance record and confirm the
    repository may redistribute it; no renderer code changes in this unit.
  - **Depends:** Task 10D and the real-time UI checkpoint.
- [x] **Task 11B — Implement canvas initialization, resize, and disposal.**
  - **Done when:** typed effects initialize one fixed canvas renderer, observe its
    content box/DPR, dispatch ready/resize/error, and dispose observers/listeners/
    frames/image references idempotently.
  - **Files:** `src/pixel_scribe_frontend/canvas.gleam`,
    `src/pixel_scribe_frontend/canvas_ffi.mjs`,
    `src/pixel_scribe_frontend/view.gleam`,
    `src/pixel_scribe_frontend/runtime.gleam`,
    `src/pixel_scribe_frontend/update.gleam`.
  - **Verify:** format/build; review the complete FFI export and handle lifecycle;
    add only boundary tests supported without production test globals.
  - **Depends:** Task 11A.
- [x] **Task 11C — Render static layers, assets, and fallback geometry.**
  - **Done when:** cached assets draw floor/walls, furniture, Y-sorted avatars,
    names/self accents, and an empty bubble pass; load failure draws a useful
    fallback and reports only safe typed status.
  - **Files:** `src/pixel_scribe_frontend/canvas.gleam`,
    `src/pixel_scribe_frontend/canvas_ffi.mjs`,
    `src/pixel_scribe_frontend/scene.gleam`,
    `src/pixel_scribe_frontend/model.gleam`,
    `src/pixel_scribe_frontend/update.gleam`,
    `src/pixel_scribe_frontend/runtime.gleam`,
    `src/pixel_scribe_frontend/view.gleam`, `e2e/canvas.spec.ts`.
  - **Verify:** all Gleam checks, production bundle, and focused fallback/layer
    browser assertions.
  - **Depends:** Task 11B.
- [x] **Task 11D — Apply camera crop, DPR scaling, and culling.**
  - **Done when:** world-to-viewport transform precedes DPR scaling, smoothing is
    off, device geometry is rounded, crop/backdrop behavior is correct at edges,
    and offscreen entities are culled without leaving semantic DOM.
  - **Files:** `src/pixel_scribe_frontend/canvas.gleam`,
    `src/pixel_scribe_frontend/canvas_ffi.mjs`,
    `src/pixel_scribe_frontend/model.gleam`,
    `src/pixel_scribe_frontend/update.gleam`,
    `src/pixel_scribe_frontend/runtime.gleam`,
    `src/pixel_scribe_frontend/view.gleam`, `e2e/canvas.spec.ts`.
  - **Verify:** fixed-seed DPR 1/2 tests for center invariance, resize, peer churn,
    reconnect target, and edge backdrop.
  - **Depends:** Task 11C.
- [x] **Task 11E — Implement dirty-frame scheduling.**
  - **Done when:** frames run only for init/resize/asset-ready/dirty/active-animation
    causes, delayed delta clamps to 100ms, a static scene reaches zero pending
    frames, and disposal cannot schedule another frame.
  - **Files:** `src/pixel_scribe_frontend/canvas.gleam`,
    `src/pixel_scribe_frontend/canvas_ffi.mjs`, `e2e/canvas.spec.ts`.
  - **Verify:** focused lifecycle browser tests plus all Gleam checks and bundle.
  - **Depends:** Task 11D.
- [x] **Task 11F — Capture and approve the baseline scene.**
  - **Done when:** deterministic 320px/desktop and crowded screenshots show a
    recognizable original office, crisp sprite scale, useful fallback, and no
    invalid anchors; human approval and provenance review are recorded.
  - **Files:** `e2e/canvas.spec.ts`, `e2e/canvas.spec.ts-snapshots/`.
  - **Verify:** focused Chromium canvas suite with no console/page errors; stop at
    the human visual checkpoint.
  - **Depends:** Task 11E.

**Implementation notes:**

1. Use an original or provenance-reviewed `16px` tile atlas and small fixed-avatar
   atlas. Record creator/source/license and every modification. Do not copy Pixel
   Agents art without an asset-specific compatible license.
2. FFI initializes/disposes one renderer for the fixed canvas ID, loads/caches
   images once, observes the container, detects DPR changes, schedules/cancels
   rAF, and dispatches typed ready/resize/error events.
3. Keep world, viewport, CSS, and backing pixels separate. Size the viewport from
   the canvas content box, center it on the self avatar through the pure camera,
   render only the visible world crop, fill out-of-world areas with the backdrop,
   round device coordinates, disable smoothing, and handle DPR 1/2 plus resize.
4. Render visible floor/walls, furniture, Y-sorted avatars, self/name accents,
   then the bubble layer (empty until Task 12). Cull entities outside the camera
   crop without removing them from semantic DOM. Provide visible fallback
   geometry/avatar when an asset fails and an accessible DOM status only when
   failure affects usefulness.
5. Render only on initialization, resize, scene dirtiness, asset readiness, or an
   active animation. Clamp delayed frame delta to 100ms and fully dispose observer,
   listeners, image references, and pending frame.

**Acceptance criteria:**

- [x] Approved assets/fallback render a recognizable Pixel-Agents-inspired but
  original office with up to 50 locally placed avatars and documented provenance.
- [x] Scene remains crisp/aspect-correct at DPR 1/2 and required viewport sizes;
  resize does not accumulate observers/frames or blur coordinates.
- [x] Self stays centered while the world crop moves after self placement changes;
  peer changes do not move the crop, and edge positions show backdrop rather than
  displacing self. A static scene reaches zero pending animation frames.

**Verification:**

- [x] Pure coordinate/layer tests pass and FFI has a narrow reviewed export list.
- [x] `gleam format --check src test`
- [x] `gleam build`
- [x] `gleam test`
- [x] `gleam run -m lustre/dev build`
- [x] Playwright uses fixed seed/DPR to capture a small set of approved 320px and
  desktop screenshots; checks center invariance, self/peer placement changes,
  reconnect target, resize, edge backdrop, fallback, and no console/page errors.
- [x] Human approves scene, palette, sprite scale, crowded view, and provenance.

**Dependencies:** Task 10 and real-time UI checkpoint.

**Files likely touched:**

- `src/pixel_scribe_frontend/canvas.gleam`
- `src/pixel_scribe_frontend/canvas_ffi.mjs`
- `src/pixel_scribe_frontend/scene.gleam`
- `assets/pixel-art/` source atlases and provenance
- `e2e/canvas.spec.ts`

**Estimated scope:** Medium, 4 code/test areas plus small reviewed assets.
