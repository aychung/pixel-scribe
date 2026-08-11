## Task 6: Deliver username-to-room-state joining through native WebSocket

**Description:** Add the native WebSocket effect and complete the first vertical
slice: username submit, connection, exactly one join, decoded `room_state`, and
minimal joined status. Reconcile the final backend error/close contract first.

### Work units

- [x] **Task 6A — Freeze the backend connection/error fixtures.**
  - **Done when:** backend Task 7's implemented room context, recoverability,
    close order, and post-error phase match the canonical spec, frontend plan,
    and protocol fixtures; every difference is resolved in docs before socket
    code begins.
  - **Files:** `test/pixel_scribe_frontend/protocol_test.gleam`.
  - **Verify:** compare every error code and fixture line by line; run format,
    build, and `gleam test`. If any source document differs, stop and request a
    separate reviewed contract-reconciliation unit instead of editing it here.
  - **Depends:** foundation checkpoint and completed backend Task 7.
- [x] **Task 6B — Implement native WebSocket lifecycle externals.**
  - **Done when:** one socket per generation derives same-origin `/ws`, accepts
    text callbacks only, dispatches typed open/message/error/close facts, supports
    text send/deliberate close, removes listeners, and logs no payload.
  - **Files:** `src/pixel_scribe_frontend/socket.gleam`,
    `src/pixel_scribe_frontend/socket_ffi.mjs`.
  - **Verify:** unit-test URL derivation including HTTPS to WSS; format/build;
    review every FFI export and listener cleanup path.
  - **Depends:** Task 6A.
- [x] **Task 6C — Interpret socket commands and decode inbound frames.**
  - **Done when:** the command interpreter opens/sends/closes by generation,
    decodes before dispatch to update, safely ignores unknown event types, and
    turns malformed known frames into the documented protocol failure.
  - **Files:** `src/pixel_scribe_frontend/socket.gleam`,
    `src/pixel_scribe_frontend/update.gleam`.
  - **Verify:** focused command/ingress tests plus all Gleam checks.
  - **Depends:** Task 6B.
- [x] **Task 6D — Prove the join-to-snapshot browser slice.**
  - **Done when:** routed `/ws` observes exactly one canonical join after open,
    an oversized final join frame shows inline feedback without opening a socket,
    the entry UI exposes connecting/awaiting status before a matching snapshot,
    room state exposes a minimal joined status, and `ws:` behavior has no
    console/page errors. Task 7 still owns the participant/chat workspace.
  - **Files:** `e2e/join.spec.ts`, `e2e/app_shell.spec.ts` only to route sockets
    for existing submit coverage, `src/pixel_scribe_frontend/view.gleam`,
    `test/pixel_scribe_frontend/view_test.gleam`, and
    `src/pixel_scribe_frontend/update.gleam` only if the test exposes a missing
    documented transition.
  - **Verify:** production build and focused Chromium join test.
  - **Depends:** Task 6C.
- [x] **Task 6E — Prove join race and malformed-frame defenses.**
  - **Done when:** browser-routable duplicate submit, pre-snapshot deltas,
    wrong-room frames, malformed known frames, and unknown future types follow
    their specified safe paths in browser tests. Injected pure transition tests
    prove late old-generation callbacks are ignored; the native boundary removes
    listeners when a routed socket closes, so Playwright cannot manufacture such
    a callback without a forbidden application test hook.
  - **Files:** `e2e/join.spec.ts`, `src/pixel_scribe_frontend/update.gleam` only for
    a documented missing transition.
  - **Verify:** all Gleam checks and the full Chromium suite.
  - **Depends:** Task 6D.

**Implementation notes:**

1. Before coding, compare backend Task 7 implementation/tests/spec with the error
   table in `plan.md`. Update documentation/fixtures through review if they differ.
2. Derive `/ws` from `window.location`: `wss:` for HTTPS and `ws:` otherwise,
   same host/port. Production code gets no undocumented cross-origin override.
3. FFI opens one native `WebSocket` for a generation, accepts text only, dispatches
   open/message/error/close with generation, supports explicit close and text
   send, removes listeners, and never logs frames.
4. On open, send exactly one canonical `join_room` for `default`. Decode frames
   before they enter state. Ignore unknown future event types; block malformed
   known payloads as protocol failures.
5. In Playwright, call `page.routeWebSocket('/ws', ...)` before `page.goto`, assert
   the exact join frame, and send a fixture snapshot. Do not create a second mock
   server or mutate the application model.

**Acceptance criteria:**

- [x] A valid username opens one same-origin socket, emits one join after open,
  waits for matching `room_state`, and only then enters the joined model state
  that Task 7 will use to expose chat.
- [x] A second submit, late old-generation callback, pre-snapshot delta, malformed
  known frame, and unknown future event follow the documented safe paths.
- [x] The implemented frontend/backend error room context, recoverability, close
  order, and post-error phases are represented by matching fixtures.

**Verification:**

- [x] `gleam format --check src test`
- [x] `gleam build`
- [x] `gleam test`
- [x] `gleam run -m lustre/dev build`
- [x] Focused Playwright join test passes for `ws:` and URL derivation is unit
  tested for `https:` -> `wss:`.
- [x] `bunx playwright test --project=chromium --reporter=line --workers=1`

**Dependencies:** Foundation checkpoint and finalized backend Task 7 contract.

**Files likely touched:**

- `src/pixel_scribe_frontend/socket.gleam`
- `src/pixel_scribe_frontend/socket_ffi.mjs`
- `src/pixel_scribe_frontend/update.gleam`
- `src/pixel_scribe_frontend/view.gleam`
- `test/pixel_scribe_frontend/protocol_test.gleam`
- `test/pixel_scribe_frontend/socket_test.gleam`
- `test/pixel_scribe_frontend/update_test.gleam`
- `test/pixel_scribe_frontend/view_test.gleam`
- `e2e/join.spec.ts`
- `e2e/app_shell.spec.ts`

**Actual scope:** Medium, 10 files plus aligned task/README documentation.
