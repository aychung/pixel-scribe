## Task 7: Deliver the joined presence and status workspace

**Description:** Render the accessible joined layout and apply presence changes
by connection ID. This slice makes duplicate usernames, self identity, connection
status, canvas placeholder, participant count/list, chat log, and composer state
visible and testable.

### Work units

- [ ] **Task 7A — Render the joined semantic workspace.**
  - **Done when:** joined view exposes status, participant count/list, canvas
    placeholder, empty chat log, labeled composer, and correct disabled/busy
    semantics before/during recovery.
  - **Files:** `src/pixel_scribe_frontend/view.gleam`, `assets/styles.css`.
  - **Verify:** focused view assertions plus format, build, test, and bundle.
  - **Depends:** Task 6E.
- [ ] **Task 7B — Apply presence deltas by connection ID.**
  - **Done when:** snapshot/join/leave upsert or remove only opaque IDs, duplicate
    usernames remain distinct, duplicate joins are idempotent, unknown leaves are
    harmless, and wrong-room deltas follow protocol-failure policy.
  - **Files:** `src/pixel_scribe_frontend/update.gleam`,
    `test/pixel_scribe_frontend/update_test.gleam`.
  - **Verify:** focused failing presence tests plus all Gleam checks.
  - **Depends:** Task 7A.
- [ ] **Task 7C — Render participant identity safely.**
  - **Done when:** participant DOM keys by connection ID, only `self_id` receives
    “You”, raw IDs are not user-facing, and duplicate/XSS-like/long labels remain
    literal text without altering roles.
  - **Files:** `src/pixel_scribe_frontend/view.gleam`,
    `test/pixel_scribe_frontend/view_test.gleam`.
  - **Verify:** focused view tests plus all Gleam checks.
  - **Depends:** Task 7B.
- [ ] **Task 7D — Prove joined presence in the browser.**
  - **Done when:** routed snapshots and deltas produce exact visible counts/lists
    at 320px and 1024px, duplicate labels stay distinct, and joined-state axe plus
    console/page-error checks pass.
  - **Files:** `e2e/presence.spec.ts`, `e2e/support/accessibility.ts` only if the
    shared helper needs a documented extension.
  - **Verify:** focused Chromium presence test and joined-state axe scan.
  - **Depends:** Task 7C.

**Implementation notes:**

1. Desktop uses a flexible office column and fixed chat rail; mobile stacks the
   office over chat. The canvas remains a semantic placeholder until Task 11.
2. Render participants as a keyed semantic list by connection ID. Display names
   may repeat; mark only `self_id` as “You”. Never expose raw IDs as user-facing
   identity unless a diagnostic explicitly requires it.
3. Upsert `user_joined` by ID, remove only the matching `user_left` ID, ignore an
   idempotent duplicate/unknown leave, and ignore wrong-room deltas as protocol
   failures per the state table.
4. Add a polite connection-status region, participant count, empty chat state,
   independently scrollable log, labeled composer, and correct disabled/busy
   semantics before snapshot or during recovery.
5. Render all content through Lustre text nodes. Include duplicate-name and XSS-like
   fixture strings in unit/browser tests.

**Acceptance criteria:**

- [ ] Snapshot users plus join/leave deltas produce the exact participant count
  and list by opaque ID, including duplicate labels and self marker.
- [ ] Joined layout exposes status, participants, message-log empty state, and a
  labeled enabled composer through semantic DOM while canvas remains optional.
- [ ] User strings render literally as text and cannot change document structure
  or accessible roles.

**Verification:**

- [ ] Update/view tests cover snapshot replacement, duplicate names, idempotent
  join/leave, self marker, roles, labels, and safe text.
- [ ] `gleam format --check src test`
- [ ] `gleam build`
- [ ] `gleam test`
- [ ] Playwright routed-socket presence tests pass at 320px and 1024px.
- [ ] Axe joined-state scan has no A/AA violations.

**Dependencies:** Task 6.

**Files likely touched:**

- `src/pixel_scribe_frontend/model.gleam`
- `src/pixel_scribe_frontend/update.gleam`
- `src/pixel_scribe_frontend/view.gleam`
- `assets/styles.css`
- `e2e/presence.spec.ts`

**Estimated scope:** Medium, 5 files.

