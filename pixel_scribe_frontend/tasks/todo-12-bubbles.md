## Task 12: Connect accepted messages to temporary speech bubbles

**Description:** Add per-participant bubble state and connect unique accepted
`message_sent` events to a six-second, clamped, replaceable, accessible-by-DOM
visual overlay. Reuse the timer/dirty renderer boundaries; do not add chat state
to JavaScript.

### Work units

- [x] **Task 12A — Add bubble ownership to pure scene/update state.**
  - **Done when:** only unique live accepted messages after room state create a
    sender-ID-owned bubble, newer message replaces it, leave clears it, duplicate
    event does nothing, and snapshot history never creates bubbles.
  - **Files:** `src/pixel_scribe_frontend/scene.gleam`,
    `src/pixel_scribe_frontend/update.gleam`,
    `test/pixel_scribe_frontend/scene_test.gleam`.
  - **Verify:** failing ownership/snapshot/replace/leave tests first, then all
    Gleam checks.
  - **Depends:** Tasks 8E and 11F.
- [x] **Task 12B — Implement explicit-line bubble layout.**
  - **Done when:** layout splits LF before wrapping, caps at three visual lines,
    adds ellipsis only when truncated, anchors over the avatar, and clamps within
    every tested camera edge while preserving full DOM text.
  - **Files:** `src/pixel_scribe_frontend/scene.gleam`,
    `test/pixel_scribe_frontend/scene_test.gleam`.
  - **Verify:** multiline/wrap/truncate/emoji/edge tests plus all Gleam checks.
  - **Depends:** Task 12A.
- [x] **Task 12C — Implement bubble timing and reduced motion.**
  - **Done when:** each bubble is fully visible 5s then fades 1s, replacement
    invalidates stale timers, reduced motion removes fade, only the next required
    frame/timer is scheduled, and renderer sleeps after expiry.
  - **Files:** `src/pixel_scribe_frontend/scene.gleam`,
    `src/pixel_scribe_frontend/canvas.gleam`,
    `test/pixel_scribe_frontend/scene_test.gleam`.
  - **Verify:** fixed-clock lifecycle tests plus all Gleam checks.
  - **Depends:** Task 12B.
- [x] **Task 12D — Prove bubbles in the browser.**
  - **Done when:** routed accepted messages show full multiline DOM text and the
    correct owned canvas bubble before/during/after fade; replace, leave, reduced
    motion, and snapshot-no-replay cases pass without duplicate announcements.
  - **Files:** `e2e/bubbles.spec.ts`.
  - **Verify:** focused Chromium bubble suite with fixed clock/seed/DPR.
  - **Depends:** Task 12C.

**Implementation notes:**

1. On a unique accepted message whose sender is present, create/replace that
   sender's bubble using message ID, safe text, start/expiry times, and named
   `5,000ms` fully visible plus `1,000ms` fade constants.
2. A participant leave clears its bubble. Snapshot history does not create a wall
   of old bubbles; only live `message_sent` after the current `room_state` does.
3. Pure text layout splits accepted LF first, then wraps each explicit line to a
   fixed logical width, caps the result at three visual lines, appends a visual
   ellipsis when truncated, anchors above the avatar, and clamps the bubble
   rectangle within the current camera viewport. The full accepted text remains
   in the DOM.
4. Schedule only the next required expiry/fade frame. Newer bubble invalidates the
   old timer by identity. Reduced-motion keeps the bubble then removes it at
   expiry without opacity animation.
5. Do not announce canvas bubbles separately to assistive technology; the chat
   log's accepted message is the one semantic announcement.

**Acceptance criteria:**

- [x] Live accepted messages create one correctly owned bubble by sender ID;
  duplicate events do not, newer messages replace, leave clears, and snapshots
  do not replay bubbles.
- [x] Wrapping, three-line truncation, edge clamping, 5s/1s lifecycle, stale timer,
  reduced-motion, and full-DOM-text invariants have deterministic tests.
- [x] Renderer sleeps after the final bubble expires and never requires a
  permanent loop for fixed avatars.

**Verification:**

- [x] Fixed-clock Gleam scene/update tests fail first, then pass.
- [x] `gleam format --check src test`
- [x] `gleam build`
- [x] `gleam test`
- [x] Playwright routed message produces both full DOM log text and approved
  canvas bubble snapshots before fade, during fade, and after expiry.
- [x] `bunx playwright test e2e/bubbles.spec.ts --project=chromium --reporter=line --workers=1`

**Dependencies:** Tasks 8 and 11.

**Files likely touched:**

- `src/pixel_scribe_frontend/scene.gleam`
- `src/pixel_scribe_frontend/update.gleam`
- `src/pixel_scribe_frontend/canvas.gleam`
- `test/pixel_scribe_frontend/scene_test.gleam`
- `e2e/bubbles.spec.ts`

**Estimated scope:** Medium, 5 files.
