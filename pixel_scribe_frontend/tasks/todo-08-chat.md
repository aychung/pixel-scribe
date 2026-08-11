## Task 8: Deliver accepted-message chat without optimistic rendering

**Description:** Complete the chat vertical slice: validate and send one in-flight
multiline message through a textarea, append only accepted `message_sent` events,
preserve/clear the draft at the documented moments, deduplicate, bound history,
and manage useful scrolling.

### Work units

- [x] **Task 8A — Implement the multiline composer interaction.**
  - **Done when:** textarea input is controlled, validation uses Task 3B, Enter
    submits, Shift+Enter inserts LF, IME composition never submits, invalid input
    remains with inline feedback, and an oversized final `send_message` frame is
    rejected locally without a socket send.
  - **Files:** `src/pixel_scribe_frontend/view.gleam`,
    `src/pixel_scribe_frontend/update.gleam`,
    `test/pixel_scribe_frontend/view_test.gleam`.
  - **Verify:** failing keyboard/validation view tests first, then all Gleam checks.
  - **Depends:** Tasks 3B and 7D.
- [x] **Task 8B — Implement send-in-flight and accepted echo behavior.**
  - **Done when:** valid submit sends without appending, repeat submit is blocked,
    accepted peer/self messages append once, matching self echo clears the draft,
    and server invalid/rate errors preserve it.
  - **Files:** `src/pixel_scribe_frontend/update.gleam`,
    `test/pixel_scribe_frontend/update_test.gleam`.
  - **Verify:** failing send/echo/error/dedup/latest-50 tests first, then all Gleam
    checks.
  - **Depends:** Task 8A.
- [x] **Task 8C — Render the safe multiline message log.**
  - **Done when:** sender/You marker, full preserved line structure, safe text,
    machine-readable timestamp, local presentation, empty/history copy, and
    non-persistence wording are correct.
  - **Files:** `src/pixel_scribe_frontend/view.gleam`,
    `src/pixel_scribe_frontend/browser.gleam`,
    `src/pixel_scribe_frontend/browser_ffi.mjs`,
    `src/pixel_scribe_frontend/protocol.gleam`,
    `test/pixel_scribe_frontend/view_test.gleam`,
    `test/pixel_scribe_frontend/browser_test.gleam`,
    `test/pixel_scribe_frontend/protocol_test.gleam`,
    `gleam.toml`, `manifest.toml`.
  - **Verify:** focused view tests with multiline, XSS-like, long, and duplicate-name
    fixtures plus all Gleam checks.
  - **Depends:** Task 8B.
- [x] **Task 8D — Implement near-bottom chat scrolling.**
  - **Done when:** own accepted send scrolls, peer messages scroll only when the
    reader was already near the bottom, the message log is an independently
    scrollable grid track, and fixed-ID browser queries safely no-op without
    exporting arbitrary DOM state.
  - **Files:** `assets/styles.css`,
    `src/pixel_scribe_frontend/browser.gleam`,
    `src/pixel_scribe_frontend/browser_ffi.mjs`,
    `src/pixel_scribe_frontend/update.gleam`,
    `src/pixel_scribe_frontend/view.gleam`,
    `test/pixel_scribe_frontend/browser_test.gleam`,
    `test/pixel_scribe_frontend/update_test.gleam`,
    `test/pixel_scribe_frontend/view_test.gleam`.
  - **Verify:** pure command-decision tests plus all Gleam checks.
  - **Depends:** Task 8C.
- [x] **Task 8E — Prove complete chat behavior in the browser.**
  - **Done when:** routed socket tests assert exact outgoing normalized JSON, no
    optimistic entry, accepted self/peer display, multiline keyboard behavior,
    draft/error handling, deduplication, and reader-preserving scroll.
  - **Files:** `e2e/chat.spec.ts`.
  - **Verify:** focused Chromium chat test, then the full Chromium suite.
  - **Depends:** Task 8D.

**Implementation notes:**

1. Normalize and validate on submit using Task 3's trusted message constructor.
   Invalid input or an oversized final frame stays in the composer with inline
   text and emits no frame; otherwise valid input sends canonical JSON, remains
   visible, and disables repeat submit while one send is in flight.
2. Do not append on submit. On a unique `message_sent`, append/bound by message ID.
   If `sender_id == self_id` and its text matches the in-flight draft, clear the
   draft/in-flight marker; otherwise treat unexpected self ordering explicitly.
3. Render sender label, “You” marker when applicable, full safe message text, and
   a machine-readable server timestamp with a local human-readable presentation.
   Do not imply durable history.
4. On `invalid_message` or `rate_limited`, clear only in-flight state, keep the
   draft, show inline feedback, and for rate limit schedule the documented
   one-second local throttle.
5. Scroll to the newest message only when already near the bottom or after the
   user's own accepted send. Preserve a reader's older position for peer messages.
6. Use a textarea: Enter sends, Shift+Enter inserts LF, and Enter does not submit
   while IME composition is active. Preserve accepted LF in the DOM log. Bubble
   layout later splits explicit lines before ordinary wrapping.

**Acceptance criteria:**

- [x] No message appears before `message_sent`; accepted self/peer events append
  once by ID, stay in server order, and the visible log remains latest-50 bounded.
- [x] Empty, over-limit, invalid-control, server invalid-message,
  rate-limit, duplicate event, disconnect-while-pending, and safe-text cases all
  preserve the right draft/UI.
- [x] Enter, Shift+Enter, and IME composition follow the approved multiline
  policy; the composer remains labeled and scrolling does not drag a reader
  downward.

**Verification:**

- [x] Update/view tests fail first for send, echo, error, dedup, bound, and draft.
- [x] `gleam format --check src test`
- [x] `gleam build`
- [x] `gleam test`
- [x] Playwright asserts outgoing JSON and user-visible results through routed WS.
- [x] `bunx playwright test e2e/chat.spec.ts --project=chromium --reporter=line --workers=1`

**Dependencies:** Task 7 and the updated canonical backend message contract.

**Files likely touched:**

- `src/pixel_scribe_frontend/model.gleam`
- `src/pixel_scribe_frontend/update.gleam`
- `src/pixel_scribe_frontend/view.gleam`
- `test/pixel_scribe_frontend/update_test.gleam`
- `e2e/chat.spec.ts`

**Estimated scope:** Medium, 5 files.
