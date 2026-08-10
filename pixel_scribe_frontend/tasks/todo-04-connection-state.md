## Task 4: Implement the deterministic connection state machine and backoff

**Description:** Expand `Model`/`Msg` and implement all connection-phase
transitions as pure state plus a closed set of external commands. This task does
not open a real WebSocket; it proves behavior before browser effects are wired.

### Work units

- [ ] **Task 4A — Define phases, model fields, messages, and commands.**
  - **Done when:** every phase and state field from `plan.md` is explicit, external
    work is a closed command type, and neither model nor commands contain browser
    handles or decoded-untrusted values.
  - **Files:** `src/pixel_scribe_frontend/model.gleam`,
    `src/pixel_scribe_frontend/update.gleam`,
    `test/pixel_scribe_frontend/model_test.gleam`,
    `test/pixel_scribe_frontend/update_test.gleam`.
  - **Verify:** construction/exhaustiveness tests; format, build, and `gleam test`;
    inspect imports for FFI/browser modules.
  - **Depends:** Tasks 1A and 3D.
- [ ] **Task 4B — Implement username, open, and snapshot transitions.**
  - **Done when:** valid submit creates one generation/open command, invalid submit
    stays local, open sends one join command, and matching room state alone enters
    joined state and resets reconnect attempts.
  - **Files:** `src/pixel_scribe_frontend/update.gleam`,
    `test/pixel_scribe_frontend/update_test.gleam`.
  - **Verify:** table-driven failing tests for each transition plus format, build,
    and `gleam test`.
  - **Depends:** Task 4A.
- [ ] **Task 4C — Implement presence, snapshot replacement, and stale rejection.**
  - **Done when:** snapshots replace by opaque ID, join/leave deltas upsert/remove
    by connection ID, wrong-generation callbacks are ignored, and duplicate
    usernames never collide.
  - **Files:** `src/pixel_scribe_frontend/update.gleam`,
    `test/pixel_scribe_frontend/update_test.gleam`.
  - **Verify:** focused snapshot/presence/generation tests plus format, build, and
    `gleam test`.
  - **Depends:** Task 4B.
- [ ] **Task 4D — Implement draft, send, echo, and deduplication transitions.**
  - **Done when:** only one send may be in flight, submit never appends, accepted
    message IDs append once and remain latest-50 bounded, self echo clears the
    matching draft, and disconnect never produces an offline replay command.
  - **Files:** `src/pixel_scribe_frontend/update.gleam`,
    `test/pixel_scribe_frontend/update_test.gleam`.
  - **Verify:** focused failing tests for peer/self/duplicate/pending/disconnect
    cases plus format, build, and `gleam test`.
  - **Depends:** Task 4C.
- [ ] **Task 4E — Implement the structured error transition table.**
  - **Done when:** every documented recoverable/terminal error maps to the approved
    phase, feedback, draft/in-flight behavior, focus command, and close/retry
    policy without an automatic error loop.
  - **Files:** `src/pixel_scribe_frontend/update.gleam`,
    `test/pixel_scribe_frontend/update_test.gleam`.
  - **Verify:** one table-driven case per phase/error pair plus format, build, and
    `gleam test`.
  - **Depends:** Task 4D.
- [ ] **Task 4F — Implement pure backoff and timer transitions.**
  - **Done when:** injected random input produces the documented capped delays and
    jitter, timer identity/generation is stale-safe, manual retry/cancel paths are
    explicit, and only room state resets attempts.
  - **Files:** `src/pixel_scribe_frontend/reconnect.gleam`,
    `test/pixel_scribe_frontend/reconnect_test.gleam`,
    `src/pixel_scribe_frontend/update.gleam`.
  - **Verify:** exact-bound and timer-transition tests plus format, build, and
    `gleam test`.
  - **Depends:** Task 4E.

**Implementation notes:**

1. Add the exact phases from `plan.md`, monotonic socket generations, optional
   stale room snapshot, draft/in-flight state, field/connection feedback,
   reconnect attempt/timer identity, and rate-limit deadline.
2. Define commands for socket open/close/send, cookie write, timer schedule/cancel,
   focus/scroll, and later scene render. Keep browser handles out of `Model`.
3. Implement pure transitions for valid/invalid username submit, socket open,
   decoded room snapshot/deltas, send request, accepted self/peer message,
   structured errors, close/error, retry timer, manual retry, and return to entry.
4. Ignore stale generation callbacks. Replace snapshots; upsert/remove presence by
   connection ID; append/deduplicate/bound messages by message ID; never key by
   username or optimistically append.
5. Implement the named backoff calculation with injected `random_unit`, cap,
   jitter bounds, and reset only on `room_state`.

**Acceptance criteria:**

- [ ] Every phase/event pair has a tested next phase and command set, including
  deliberate close versus unexpected close and stale callbacks.
- [ ] Snapshot replacement, duplicate usernames, message deduplication/latest-50,
  draft preservation, one in-flight send, and no offline replay are invariants.
- [ ] Backoff values and jitter stay within documented bounds and timers reset or
  cancel only under the documented conditions.

**Verification:**

- [ ] Table-driven state tests fail before implementation and cover all phases.
- [ ] `gleam format --check src test`
- [ ] `gleam build`
- [ ] `gleam test`
- [ ] Review that the pure transition imports no FFI/browser module.

**Dependencies:** Tasks 1 and 3.

**Files likely touched:**

- `src/pixel_scribe_frontend/model.gleam`
- `src/pixel_scribe_frontend/update.gleam`
- `src/pixel_scribe_frontend/reconnect.gleam`
- `test/pixel_scribe_frontend/update_test.gleam`
- `test/pixel_scribe_frontend/reconnect_test.gleam`

**Estimated scope:** Medium, 5 files.
