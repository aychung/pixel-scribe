## Task 9: Deliver reconnect, terminal errors, and recovery behavior

**Description:** Wire the proven reconnect/error policy to real timers, socket
generations, and user-visible states. Cover network loss, terminal server errors,
manual retry, new join/snapshot, stale events, and deliberate return to entry.

### Work units

- [x] **Task 9A — Render and enter reconnecting state.**
  - **Done when:** unexpected loss and `room_unavailable` retain visibly stale
    snapshot/draft, clear only in-flight state, disable send, schedule reconnect,
    and expose immediate retry without replay.
  - **Files:** `src/pixel_scribe_frontend/update.gleam`,
    `src/pixel_scribe_frontend/view.gleam`,
    `test/pixel_scribe_frontend/update_test.gleam`.
  - **Verify:** failing close/error view-transition tests first, then all Gleam
    checks.
  - **Depends:** Task 8E and finalized backend room-unavailable behavior.
- [x] **Task 9B — Wire retry timers and replacement generations.**
  - **Done when:** timed/immediate retry cancels the prior timer, increments the
    socket generation, stale callbacks cannot win, new room state alone resets
    backoff, and no draft-send command appears automatically.
  - **Files:** `src/pixel_scribe_frontend/reconnect.gleam`,
    `src/pixel_scribe_frontend/update.gleam`,
    `test/pixel_scribe_frontend/update_test.gleam`.
  - **Verify:** fixed-random/timer transition tests plus all Gleam checks.
  - **Depends:** Task 9A.
- [x] **Task 9C — Implement terminal retry and return-to-entry behavior.**
  - **Done when:** protocol failure and room full enter distinct blocked states,
    explicit retry opens a fresh generation, return-to-entry cancels/closes and
    clears room identity while preserving preference, and late close is ignored.
  - **Files:** `src/pixel_scribe_frontend/update.gleam`,
    `src/pixel_scribe_frontend/view.gleam`,
    `test/pixel_scribe_frontend/update_test.gleam`.
  - **Verify:** focused terminal/manual-action tests plus all Gleam checks.
  - **Depends:** Task 9B.
- [x] **Task 9D — Prove reconnect and no-replay behavior in the browser.**
  - **Done when:** fixed clock/randomness proves multiple socket generations,
    immediate/timed retries, draft preservation, no automatic send, stale callback
    rejection, new `self_id`, and snapshot replacement without real-time sleeps.
  - **Files:** `e2e/reconnect_errors.spec.ts`.
  - **Verify:** focused Chromium reconnect tests with retained trace on failure.
  - **Depends:** Task 9C.
- [x] **Task 9E — Prove the full error inventory in the browser.**
  - **Done when:** every recoverable and terminal backend error has an assertion
    for visible feedback, phase, focus, socket state, draft/in-flight behavior,
    retry control, and absence of loops or console/page errors.
  - **Files:** `e2e/reconnect_errors.spec.ts`.
  - **Verify:** full Chromium suite.
  - **Depends:** Task 9D and finalized backend Tasks 7-9 behavior.

**Implementation notes:**

1. Unexpected close/error and `room_unavailable` enter timed reconnect; show the
   stale snapshot with a clear stale/reconnecting label, keep draft, disable send,
   and expose immediate retry. Do not replay the draft.
2. Each retry cancels the prior timer, increments generation, opens a socket, and
   joins after open. Only `room_state` resets attempt/backoff and replaces
   snapshot/`self_id`; retain placements later only for IDs still present.
3. `invalid_event`/malformed known server payload enters blocked protocol UI;
   `room_full` enters blocked join UI; both require explicit new-socket retry.
   Implement every recoverable error in the approved matrix without a loop.
4. Deliberate return to username entry cancels timers, closes the active socket,
   ignores its late callbacks, preserves the preference, and clears room identity.
5. Use fixed jitter and Playwright Clock for tests. Verify multiple socket
   creations and their frames; never wait real 30-second delays.

**Acceptance criteria:**

- [x] Backoff/jitter, immediate retry, timer cancellation, generation rejection,
  and reset-after-snapshot match the pure policy under browser integration.
- [x] Reconnect preserves draft without sending it, keeps stale content visibly
  marked, then replaces snapshot/`self_id` and resumes only after `room_state`.
- [x] Every recoverable and terminal error produces the approved inline/blocked,
  socket, focus, retry, and phase behavior with no automatic error loop.

**Verification:**

- [x] `gleam format --check src test`
- [x] `gleam build`
- [x] `gleam test`
- [x] Focused Playwright reconnect/error test runs with fixed clock/randomness and
  retained trace on failure.
- [x] Assert the routed socket receives no `send_message` after reconnection until
  the user submits again.
- [x] Full Chromium suite passes without real-time sleeps or flaky retries.

**Dependencies:** Task 8 and finalized backend Tasks 7-9 error behavior.

**Files likely touched:**

- `src/pixel_scribe_frontend/reconnect.gleam`
- `src/pixel_scribe_frontend/update.gleam`
- `src/pixel_scribe_frontend/socket.gleam`
- `src/pixel_scribe_frontend/view.gleam`
- `e2e/reconnect_errors.spec.ts`

**Estimated scope:** Medium, 5 files.
