## Task 5: Add browser preference and small DOM effects

**Description:** Implement narrow Lustre effects for the username cookie,
placement seed, reconnect/rate/bubble timers, focus, and chat scrolling. Wire
initial preference loading without granting JavaScript ownership of app state.

### Work units

- [ ] **Task 5A — Implement the pure cookie contract.**
  - **Done when:** only `pixel_scribe_username` is parsed/serialized; valid Unicode
    round-trips through percent encoding; invalid/missing values become no
    preference; and attributes exactly match the HTTPS/non-HTTPS policy.
  - **Files:** `src/pixel_scribe_frontend/browser.gleam`,
    `test/pixel_scribe_frontend/browser_test.gleam`.
  - **Verify:** focused cookie policy tests plus format, build, and `gleam test`.
  - **Depends:** Tasks 3B and 4F.
- [ ] **Task 5B — Add cookie and secure-seed browser externals.**
  - **Done when:** narrow typed externals read/write only the named cookie and use
    `crypto.getRandomValues` for a page seed, with no logging or production test
    global.
  - **Files:** `src/pixel_scribe_frontend/browser.gleam`,
    `src/pixel_scribe_frontend/browser_ffi.mjs`.
  - **Verify:** `gleam format --check src test`; `gleam build`; review the complete
    FFI export list and failure paths.
  - **Depends:** Task 5A.
- [ ] **Task 5C — Add typed timer effects and cleanup.**
  - **Done when:** schedule/cancel effects dispatch timer identity and generation,
    remove fired/cancelled handles, and stale callbacks cannot affect replacement
    state.
  - **Files:** `src/pixel_scribe_frontend/browser.gleam`,
    `src/pixel_scribe_frontend/browser_ffi.mjs`.
  - **Verify:** focused timer boundary tests where possible; format, build, and
    `gleam test`; inspect cleanup branches.
  - **Depends:** Task 5B.
- [ ] **Task 5D — Add fixed-target focus and chat-scroll effects.**
  - **Done when:** focus and scroll commands target only fixed application-owned
    IDs, report only typed facts needed by update, and safely no-op after removal.
  - **Files:** `src/pixel_scribe_frontend/browser.gleam`,
    `src/pixel_scribe_frontend/browser_ffi.mjs`.
  - **Verify:** format, build, and `gleam test`; review that no arbitrary selector,
    text, cookie, or DOM snapshot crosses the FFI.
  - **Depends:** Task 5C.
- [ ] **Task 5E — Wire startup preference and browser behavior.**
  - **Done when:** init loads a validated preference and seed through effects,
    valid submit writes the cookie, validation failure focuses the username field,
    and Playwright proves Unicode prefill plus exact cookie attributes.
  - **Files:** `src/pixel_scribe_frontend.gleam`,
    `src/pixel_scribe_frontend/update.gleam`, `e2e/app_shell.spec.ts`.
  - **Verify:** all Gleam checks, production bundle, and focused Chromium shell/
    cookie tests.
  - **Depends:** Tasks 2C and 5D.

**Implementation notes:**

1. Parse/serialize only the named cookie. Percent-encode the value, use
   `Max-Age=15552000`, `Path=/`, `SameSite=Strict`, omit `Domain`, add `Secure`
   only for HTTPS, and never set `HttpOnly` from JavaScript.
2. Treat a missing/malformed/invalid saved username as no preference; do not show
   a scary error. Prefill only after normal frontend validation.
3. Use `crypto.getRandomValues` for a non-security-sensitive page placement seed
   with a deterministic test injection path that is not a production global.
4. Timer callbacks dispatch typed messages containing timer identity/generation.
   Focus and scroll commands target fixed application-owned IDs and safely no-op
   if the element is gone.
5. Keep FFI exports narrow and typed. Register and clean up handles; do not put
   cookies, seed values, text, or DOM snapshots in logs.

**Acceptance criteria:**

- [ ] A valid saved username is prefilled, invalid cookie data is ignored, and a
  valid submit writes the exact Strict 180-day preference attributes.
- [ ] Timer/focus/scroll callbacks are typed and stale-safe, with cleanup paths
  that cannot affect a replacement generation.
- [ ] Browser FFI owns handles only; cookie parsing/serialization and policy are
  independently unit-tested.

**Verification:**

- [ ] `gleam format --check src test`
- [ ] `gleam build`
- [ ] `gleam test`
- [ ] Add Playwright checks for prefill, encoded Unicode, Strict/Path/Max-Age,
  and keyboard focus after validation failure; unit-test HTTPS-conditional Secure
  serialization.
- [ ] `bunx playwright test --project=chromium --reporter=line --workers=1`

**Dependencies:** Tasks 2 and 4.

**Files likely touched:**

- `src/pixel_scribe_frontend/browser.gleam`
- `src/pixel_scribe_frontend/browser_ffi.mjs`
- `src/pixel_scribe_frontend.gleam`
- `src/pixel_scribe_frontend/update.gleam`
- `test/pixel_scribe_frontend/browser_test.gleam`

**Estimated scope:** Medium, 5 files.

