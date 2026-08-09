# Pixel Scribe Frontend MVP Tasks

This checklist executes [`plan.md`](plan.md) against the canonical frontend and
backend specifications. Complete tasks in dependency order. Do not implement a
later task merely because a nearby file is already open.

## Execution Rules

- [x] Human approval of `plan.md` and this checklist recorded on 2026-08-09.
- Treat every numbered Task 0-15 as a macro/checkpoint, not as one implementation
  assignment. Implement exactly one unchecked lettered work unit (for example,
  Task 3B) per turn. Never combine adjacent units merely because they share a
  file.
- Before a work unit, read its parent task, the named dependency units, and only
  the relevant sections of `plan.md`, `README.md`, and the canonical backend
  specification. Inspect every listed file before editing it.
- The work unit's **Files** list is its allowed edit scope. If another production
  file is required, stop and update this checklist through review before editing
  it. Generated dependency lockfiles named by the unit are allowed outputs of
  the documented package-manager command.
- Start behavior units with the stated failing test. A unit is complete only when
  its **Done when** statement is true and every **Verify** command passes. Record
  the evidence, inspect `jj diff`, and stop; do not begin the next unit.
- Keep the working application buildable after every unit. A parent macro task is
  complete only after all of its lettered units and its parent acceptance criteria
  pass.
- Preserve unrelated working-copy changes and inspect `jj status` before and
  after each lettered work unit. Each work unit is one review-sized change.
- Start behavior changes with the narrowest failing test or fixture. Do not mark
  a checkbox until its stated verification has actually passed.
- Use `gleam add` for Gleam dependencies and Bun tooling for JavaScript test
  dependencies. Never hand-edit `manifest.toml`, `bun.lock`, or generated JS.
- Decode all network/browser data at its boundary. Do not log usernames, message
  text, cookies, raw frames, malformed payloads, or browser storage.
- Keep usernames, IDs, messages, and server errors text-safe. No HTML injection,
  raw DOM mutation, `innerHTML`, or string-built markup.
- Run Chromium Playwright tests through the non-interactive CLI with one worker
  while implementing. Use interactive/headed tooling only when explicitly
  requested or needed for a human diagnostic.
- Stop at every checkpoint for review. If the canonical backend contract and the
  implemented backend differ, reconcile documentation and fixtures before
  changing frontend behavior.
- For Lustre, Playwright, Canvas, cookie, or WebSocket APIs, use the official
  references linked from `plan.md` for the versions locked by Task 0. If the
  documented API cannot express the unit as written, stop and report the exact
  mismatch instead of inventing an FFI or adding a dependency.

## Work-unit handoff prompt

Use this prompt when assigning a unit to a smaller model:

```text
Implement only Task <ID> from tasks/todo.md. Read the execution rules, its parent
macro task, named dependencies, and the relevant contract sections first. Edit
only its Files list. Start with the stated failing test when behavior changes.
Meet Done when, run every Verify command, inspect jj diff/status, report evidence,
and stop without starting the next unit. If a contract, API, file-scope, or
dependency mismatch appears, stop and report it rather than guessing.
```

## Task 0: Lock the frontend toolchain and artifact policy

**Description:** Add only the approved runtime/build/test dependencies, configure
Lustre's official build, establish Bun/Playwright scripts, and ignore generated
artifacts. This task creates a deterministic foundation but no product behavior.

### Work units

- [ ] **Task 0A — Resolve Gleam dependencies.**
  - **Done when:** `lustre` and `gleam_json` are direct dependencies,
    `lustre_dev_tools` remains development-only, and the generated manifest diff
    contains no unexplained direct package.
  - **Files:** `gleam.toml`, `manifest.toml`.
  - **Verify:** `gleam deps download`; `gleam build`; inspect the complete lockfile
    diff.
  - **Depends:** approved plan.
- [ ] **Task 0B — Resolve browser-test dependencies and scripts.**
  - **Done when:** Bun is pinned in `packageManager`, only Playwright and axe are
    direct development dependencies, and scripts expose the documented headless
    test commands without installing browsers.
  - **Files:** `package.json`, `bun.lock`.
  - **Verify:** `bun install --frozen-lockfile`; `bunx playwright --version`;
    inspect dependency scripts and the complete lockfile diff.
  - **Depends:** Task 0A.
- [ ] **Task 0C — Configure Lustre output and artifact ignores.**
  - **Done when:** Lustre uses system Bun, builds a minified `dist/` app with the
    approved HTML metadata and stylesheet, Tailwind processing is disabled, and
    every generated path in the parent acceptance criteria is ignored.
  - **Files:** `gleam.toml`, `../.gitignore`.
  - **Verify:** `gleam build`; `gleam run -m lustre/dev build`; inspect `dist/` and
    `jj diff --summary` without adding generated output.
  - **Depends:** Tasks 0A-0B.

**Implementation notes:**

1. From `pixel_scribe_frontend/`, run `gleam add lustre gleam_json` and
   `gleam add lustre_dev_tools --dev`. Keep `gleeunit` as a dev dependency.
2. Add `@playwright/test` and `@axe-core/playwright` as Bun dev dependencies and
   commit the generated `bun.lock`. Record the project package manager/version.
3. Configure `tools.lustre` to use the system Bun, emit a minified production
   build into `dist/`, generate the default `#app` mount, set `lang = "en"`, set
   the page title, link `/styles.css`, and disable unrequested Tailwind behavior.
4. Add scripts for the checked-in browser commands; scripts must not install
   browsers or OS packages implicitly.
5. Ignore frontend `build/`, `dist/`, `.lustre/`, `node_modules/`, Playwright
   reports/results, and staged generated backend public output while preserving
   source assets and lockfiles.

**Acceptance criteria:**

- [ ] Gleam resolves `lustre`, `gleam_json`, and `lustre_dev_tools` through its
  tooling; Bun resolves only the approved browser-test dependencies.
- [ ] `gleam.toml`, `manifest.toml`, `package.json`, and `bun.lock` form a
  deterministic, reviewed dependency/build contract.
- [ ] Generated bundles, caches, browser binaries, traces, screenshots, and
  staged backend assets are ignored; source and lockfiles remain tracked.

**Verification:**

- [ ] Review the complete dependency and lockfile diffs; no unrelated package is
  direct and no generated lockfile was hand-edited.
- [ ] `gleam deps download`
- [ ] `gleam build`
- [ ] `bun install --frozen-lockfile`
- [ ] `bunx playwright --version`
- [ ] `jj diff --summary`

**Dependencies:** Approved plan.

**Files likely touched:**

- `gleam.toml`
- `manifest.toml`
- `package.json`
- `bun.lock`
- `../.gitignore`

**Estimated scope:** Medium, 5 files.

## Task 1: Bootstrap the explicit Lustre SPA shell

**Description:** Create the smallest browser application using
`lustre.application` and `lustre.start`, with explicit `Model`, `Msg`, `update`,
and `view`. Render a semantic username-entry shell and responsive page regions,
but do not connect a socket or render a canvas scene yet.

### Work units

- [ ] **Task 1A — Create the explicit MVU skeleton.**
  - **Done when:** the entry point mounts one `lustre.application` on `#app`, and
    explicit initial `Model`, `Msg`, and no-op/local `update` compile without any
    socket, cookie, DOM, or canvas FFI.
  - **Files:** `src/pixel_scribe_frontend.gleam`,
    `src/pixel_scribe_frontend/model.gleam`,
    `src/pixel_scribe_frontend/update.gleam`.
  - **Verify:** `gleam format --check src`; `gleam build`.
  - **Depends:** Task 0C.
- [ ] **Task 1B — Render the semantic username form.**
  - **Done when:** the view has one heading, a real labeled nickname field, native
    form submission, status/help copy, and a non-interactive office preview; input
    and submit messages update only local state.
  - **Files:** `src/pixel_scribe_frontend/view.gleam`,
    `src/pixel_scribe_frontend/update.gleam`.
  - **Verify:** `gleam format --check src`; `gleam build`;
    `gleam run -m lustre/dev build`.
  - **Depends:** Task 1A.
- [ ] **Task 1C — Style the responsive shell.**
  - **Done when:** the shell is readable without horizontal overflow at 320px,
    keyboard focus is visible, and the `768px` breakpoint and `22rem` rail are
    named CSS custom properties.
  - **Files:** `assets/styles.css`.
  - **Verify:** `gleam run -m lustre/dev build`; manually inspect generated assets
    and keyboard form submission at 320px.
  - **Depends:** Task 1B.

**Implementation notes:**

1. `main` constructs the application and mounts it on `#app`; startup failure is
   handled without logging user/browser data.
2. `Model` starts in `ChoosingUsername` with empty preference/input, no room,
   empty draft/feedback, and a placeholder scene state.
3. `Msg` initially covers username input and submit. Submission may perform only
   pure local validation until later tasks add effects.
4. `view` uses one page heading, a labeled username field with
   `autocomplete="nickname"`, a submit button, a non-interactive office preview
   region, and a status/help region. Use realistic product copy.
5. Put layout/design tokens in static `assets/styles.css`; do not introduce
   inline styles, a CSS framework, gradients, oversized cards, or generic demo UI.

**Acceptance criteria:**

- [ ] The generated page mounts one Lustre SPA on `#app` and renders without
  server components or handwritten DOM mutation.
- [ ] Username entry is usable with keyboard and native form submission, and all
  controls have visible labels/focus styling.
- [ ] The shell remains readable at 320px and has named CSS custom properties for
  the `768px` breakpoint and `22rem` rail.

**Verification:**

- [ ] `gleam format --check src`
- [ ] `gleam build`
- [ ] `gleam run -m lustre/dev build`
- [ ] Confirm `dist/index.html`, bundled JS, and copied `styles.css` exist.
- [ ] Run `gleam run -m lustre/dev start` and manually submit the form by keyboard.

**Dependencies:** Task 0.

**Files likely touched:**

- `src/pixel_scribe_frontend.gleam`
- `src/pixel_scribe_frontend/model.gleam`
- `src/pixel_scribe_frontend/update.gleam`
- `src/pixel_scribe_frontend/view.gleam`
- `assets/styles.css`

**Estimated scope:** Medium, 5 files.

## Task 2: Establish Gleam and Playwright test harnesses

**Description:** Add the standard Gleam test runner, Lustre view-test baseline,
and a deterministic Playwright setup that starts the Lustre dev server. Prove the
non-interactive CLI workflow before browser behavior becomes complex.

### Work units

- [ ] **Task 2A — Add the Gleam test entry and one view test.**
  - **Done when:** `gleam test` discovers the suite and a focused test proves the
    initial model plus one semantic username-view assertion without production
    test hooks.
  - **Files:** `test/pixel_scribe_frontend_test.gleam`,
    `test/pixel_scribe_frontend/view_test.gleam`.
  - **Verify:** `gleam format --check src test`; `gleam build`; `gleam test`.
  - **Depends:** Task 1B.
- [ ] **Task 2B — Configure deterministic Playwright execution.**
  - **Done when:** the config defines the Lustre dev server, base URL, bounded
    timeouts, ignored failure artifacts, and explicit Chromium/Firefox/WebKit
    projects with Chromium as the routine project.
  - **Files:** `playwright.config.ts`.
  - **Verify:** `bunx playwright test --list --project=chromium` starts and exits
    without downloading a browser or leaving a dev server.
  - **Depends:** Tasks 0B and 1C.
- [ ] **Task 2C — Add the shell browser and axe checks.**
  - **Done when:** the headless test covers semantic locators, keyboard submit,
    320px bounds, horizontal overflow, console/page errors, and an unsuppressed
    WCAG A/AA axe scan.
  - **Files:** `e2e/app_shell.spec.ts`, `e2e/support/accessibility.ts`.
  - **Verify:** `bunx playwright install chromium` as explicit setup, then
    `bunx playwright test e2e/app_shell.spec.ts --project=chromium --reporter=line --workers=1`.
  - **Depends:** Tasks 2A-2B.

**Implementation notes:**

1. Add the standard Gleeunit entry point and one focused model/view test; do not
   add placeholder production APIs solely to create tests.
2. Configure Playwright with `testDir`, `baseURL`, the Lustre dev command in
   `webServer`, `reuseExistingServer: !CI`, retained-on-failure traces, failure-only
   screenshots, bounded timeouts, and explicit browser projects.
3. Make Chromium the routine project. Define Firefox/WebKit projects for the
   release matrix without hiding browser installation in test execution.
4. Add an app-shell spec that checks role/name locators, keyboard submission,
   320px layout bounds, no horizontal overflow, and no unexpected page/console
   errors. Add an axe helper configured for WCAG 2 A/AA and 2.1 A/AA tags.
5. Document targeted CLI syntax in comments or test README only if configuration
   is insufficient; keep the commands in `plan.md` authoritative.

**Acceptance criteria:**

- [ ] `gleam test` discovers and runs frontend tests on the JavaScript target.
- [ ] Playwright starts/stops the frontend predictably and the Chromium shell
  test passes headlessly with `--reporter=line --workers=1`.
- [ ] Failure artifacts are written only to ignored directories, and axe scans
  the initial state without suppressing rules or excluding the application.

**Verification:**

- [ ] `gleam format --check src test`
- [ ] `gleam build`
- [ ] `gleam test`
- [ ] `gleam run -m lustre/dev build`
- [ ] `bunx playwright install chromium` (explicit environment setup)
- [ ] `bunx playwright test --project=chromium --reporter=line --workers=1`
- [ ] Review that the Playwright process exits and does not leave a dev server.

**Dependencies:** Tasks 0-1.

**Files likely touched:**

- `test/pixel_scribe_frontend_test.gleam`
- `test/pixel_scribe_frontend/view_test.gleam`
- `playwright.config.ts`
- `e2e/app_shell.spec.ts`
- `e2e/support/accessibility.ts`

**Estimated scope:** Medium, 5 files.

## Task 3: Implement trusted domain values, validation, and protocol codecs

**Description:** Define the frontend's trusted protocol types, mirror visible
backend validation, encode both client events, and decode every documented server
event at the network boundary. Additive fields and unknown future event types are
forward-compatible; malformed known events are not.

### Work units

- [ ] **Task 3A — Define opaque protocol domain values.**
  - **Done when:** room, connection, and message IDs are opaque; presence, chat
    message, server-event, and error-event values have explicit fields; and only
    safe string conversion functions expose IDs for codecs/tests.
  - **Files:** `src/pixel_scribe_frontend/domain.gleam`,
    `test/pixel_scribe_frontend/domain_test.gleam`.
  - **Verify:** start with domain construction/equality tests, then run
    `gleam format --check src test`; `gleam build`; `gleam test`.
  - **Depends:** Task 0C.
- [ ] **Task 3B — Implement username and multiline-message validation.**
  - **Done when:** username fixtures match the canonical contract and messages
    follow the exact newline normalization, control rejection, trimming,
    1-500-grapheme, and eight-line rules in `plan.md`.
  - **Files:** `src/pixel_scribe_frontend/validation.gleam`,
    `test/pixel_scribe_frontend/validation_test.gleam`.
  - **Verify:** first add failing boundary fixtures for CRLF/CR/`U+2028`/`U+2029`,
    LF, ninth line, tabs, C0/C1, DEL, emoji, and combining text; then run format,
    build, and `gleam test`.
  - **Depends:** Task 3A and the updated canonical backend message contract.
- [ ] **Task 3C — Encode canonical client events.**
  - **Done when:** join and send encoders emit only the exact snake-case JSON
    fields for room `default`, using already trusted username/message values.
  - **Files:** `src/pixel_scribe_frontend/protocol.gleam`,
    `test/pixel_scribe_frontend/protocol_test.gleam`.
  - **Verify:** exact-string/golden tests for both events; format, build, and
    `gleam test`.
  - **Depends:** Tasks 3A-3B.
- [ ] **Task 3D — Decode and reject server frames.**
  - **Done when:** every documented server event and nullable error room decodes;
    additive fields and unknown future event types are tolerated; malformed known
    events fail without retaining raw payload text.
  - **Files:** `src/pixel_scribe_frontend/protocol.gleam`,
    `test/pixel_scribe_frontend/protocol_test.gleam`.
  - **Verify:** failing fixtures first for exact, additive, unknown, missing,
    wrong-type, nullability, XSS-like, and malformed cases; format, build, and
    `gleam test`; compare fields with the canonical backend spec.
  - **Depends:** Task 3C.

**Implementation notes:**

1. Define opaque room/connection/message IDs and explicit `Presence`,
   `ChatMessage`, `ServerEvent`, `ErrorEvent`, and decode-error types. Treat
   timestamps as server-provided RFC3339 strings unless a real display operation
   requires parsed time.
2. Encode exactly:
   `join_room(room_id="default", username)` and
   `send_message(room_id="default", text)` with snake-case fields and text JSON.
3. Decode `room_state`, `user_joined`, `user_left`, `message_sent`, and `error`.
   Require documented fields/types, allow `error.room_id` string or null, ignore
   additive fields, and return a distinct safely ignored value for unknown `type`.
4. For messages, normalize CRLF, bare CR, `U+2028`, and `U+2029` to LF; reject
   every remaining C0/C1 control and DEL; trim; then enforce `1-500` Unicode
   grapheme clusters including LF and at most seven LF characters/eight lines.
   Mirror the backend's normalization order and fixtures. Do not add a Unicode
   package without review.
5. Cover XSS-like strings as ordinary text data. No decoder failure may include
   raw payload content in an application-visible/loggable value.

**Acceptance criteria:**

- [ ] Every documented event has a passing exact fixture, and client encoders
  produce the canonical JSON shape for `default`.
- [ ] Missing/wrong fields, malformed JSON, invalid nullability, and malformed
  known events fail safely; additive fields and unknown event types do not.
- [ ] Username/message validation matches backend fixtures at empty, maximum,
  over-limit, combining-character, emoji, whitespace, CRLF/CR/`U+2028`/`U+2029`
  normalization, LF, eight-line, tab, C0/C1, and DEL boundaries.

**Verification:**

- [ ] Start with failing fixture/validation tests, then implement the codecs.
- [ ] `gleam format --check src test`
- [ ] `gleam build`
- [ ] `gleam test`
- [ ] Compare fixture field names and error inventory line by line with the
  canonical backend specification and current backend protocol tests.

**Dependencies:** Task 0 and the updated canonical backend message contract.

**Files likely touched:**

- `src/pixel_scribe_frontend/domain.gleam`
- `src/pixel_scribe_frontend/validation.gleam`
- `src/pixel_scribe_frontend/protocol.gleam`
- `test/pixel_scribe_frontend/validation_test.gleam`
- `test/pixel_scribe_frontend/protocol_test.gleam`

**Estimated scope:** Medium, 5 files.

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

## Checkpoint: Foundation

- [ ] Human has approved the state transition and error-policy tables.
- [ ] `gleam format --check src test`, `gleam build`, and `gleam test` pass.
- [ ] `gleam run -m lustre/dev build` succeeds from a clean `dist/`.
- [ ] Chromium app-shell/cookie Playwright tests pass non-interactively.
- [ ] No untrusted value, browser handle, generated output, or secret entered the
  wrong boundary.

## Task 6: Deliver username-to-room-state joining through native WebSocket

**Description:** Add the native WebSocket effect and complete the first vertical
slice: username submit, connection, exactly one join, decoded `room_state`, and
joined UI enablement. Reconcile the final backend error/close contract first.

### Work units

- [ ] **Task 6A — Freeze the backend connection/error fixtures.**
  - **Done when:** backend Task 7's implemented room context, recoverability,
    close order, and post-error phase match the canonical spec, frontend plan,
    and protocol fixtures; every difference is resolved in docs before socket
    code begins.
  - **Files:** `test/pixel_scribe_frontend/protocol_test.gleam`.
  - **Verify:** compare every error code and fixture line by line; run format,
    build, and `gleam test`. If any source document differs, stop and request a
    separate reviewed contract-reconciliation unit instead of editing it here.
  - **Depends:** foundation checkpoint and completed backend Task 7.
- [ ] **Task 6B — Implement native WebSocket lifecycle externals.**
  - **Done when:** one socket per generation derives same-origin `/ws`, accepts
    text callbacks only, dispatches typed open/message/error/close facts, supports
    text send/deliberate close, removes listeners, and logs no payload.
  - **Files:** `src/pixel_scribe_frontend/socket.gleam`,
    `src/pixel_scribe_frontend/socket_ffi.mjs`.
  - **Verify:** unit-test URL derivation including HTTPS to WSS; format/build;
    review every FFI export and listener cleanup path.
  - **Depends:** Task 6A.
- [ ] **Task 6C — Interpret socket commands and decode inbound frames.**
  - **Done when:** the command interpreter opens/sends/closes by generation,
    decodes before dispatch to update, safely ignores unknown event types, and
    turns malformed known frames into the documented protocol failure.
  - **Files:** `src/pixel_scribe_frontend/socket.gleam`,
    `src/pixel_scribe_frontend/update.gleam`.
  - **Verify:** focused command/ingress tests plus all Gleam checks.
  - **Depends:** Task 6B.
- [ ] **Task 6D — Prove the join-to-snapshot browser slice.**
  - **Done when:** routed `/ws` observes exactly one canonical join after open,
    chat stays disabled before a matching snapshot, room state enables joined UI,
    and `ws:` behavior has no console/page errors.
  - **Files:** `e2e/join.spec.ts`, `src/pixel_scribe_frontend/update.gleam` only if
    the test exposes a missing documented transition.
  - **Verify:** production build and focused Chromium join test.
  - **Depends:** Task 6C.
- [ ] **Task 6E — Prove join race and malformed-frame defenses.**
  - **Done when:** duplicate submit, old-generation callbacks, pre-snapshot
    deltas, wrong-room frames, malformed known frames, and unknown future types
    all follow their specified safe paths in browser tests.
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

- [ ] A valid username opens one same-origin socket, emits one join after open,
  waits for matching `room_state`, and only then enters joined state/enables chat.
- [ ] A second submit, late old-generation callback, pre-snapshot delta, malformed
  known frame, and unknown future event follow the documented safe paths.
- [ ] The implemented frontend/backend error room context, recoverability, close
  order, and post-error phases are represented by matching fixtures.

**Verification:**

- [ ] `gleam format --check src test`
- [ ] `gleam build`
- [ ] `gleam test`
- [ ] `gleam run -m lustre/dev build`
- [ ] Focused Playwright join test passes for `ws:` and URL derivation is unit
  tested for `https:` -> `wss:`.
- [ ] `bunx playwright test --project=chromium --reporter=line --workers=1`

**Dependencies:** Foundation checkpoint and finalized backend Task 7 contract.

**Files likely touched:**

- `src/pixel_scribe_frontend/socket.gleam`
- `src/pixel_scribe_frontend/socket_ffi.mjs`
- `src/pixel_scribe_frontend/model.gleam`
- `src/pixel_scribe_frontend/update.gleam`
- `e2e/join.spec.ts`

**Estimated scope:** Medium, 5 files.

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

## Task 8: Deliver accepted-message chat without optimistic rendering

**Description:** Complete the chat vertical slice: validate and send one in-flight
multiline message through a textarea, append only accepted `message_sent` events,
preserve/clear the draft at the documented moments, deduplicate, bound history,
and manage useful scrolling.

### Work units

- [ ] **Task 8A — Implement the multiline composer interaction.**
  - **Done when:** textarea input is controlled, validation uses Task 3B, Enter
    submits, Shift+Enter inserts LF, IME composition never submits, and invalid
    input remains with inline feedback.
  - **Files:** `src/pixel_scribe_frontend/view.gleam`,
    `src/pixel_scribe_frontend/update.gleam`,
    `test/pixel_scribe_frontend/view_test.gleam`.
  - **Verify:** failing keyboard/validation view tests first, then all Gleam checks.
  - **Depends:** Tasks 3B and 7D.
- [ ] **Task 8B — Implement send-in-flight and accepted echo behavior.**
  - **Done when:** valid submit sends without appending, repeat submit is blocked,
    accepted peer/self messages append once, matching self echo clears the draft,
    and server invalid/rate errors preserve it.
  - **Files:** `src/pixel_scribe_frontend/update.gleam`,
    `test/pixel_scribe_frontend/update_test.gleam`.
  - **Verify:** failing send/echo/error/dedup/latest-50 tests first, then all Gleam
    checks.
  - **Depends:** Task 8A.
- [ ] **Task 8C — Render the safe multiline message log.**
  - **Done when:** sender/You marker, full preserved line structure, safe text,
    machine-readable timestamp, local presentation, empty/history copy, and
    non-persistence wording are correct.
  - **Files:** `src/pixel_scribe_frontend/view.gleam`,
    `test/pixel_scribe_frontend/view_test.gleam`.
  - **Verify:** focused view tests with multiline, XSS-like, long, and duplicate-name
    fixtures plus all Gleam checks.
  - **Depends:** Task 8B.
- [ ] **Task 8D — Implement near-bottom chat scrolling.**
  - **Done when:** own accepted send scrolls, peer messages scroll only when the
    reader was already near the bottom, and fixed-ID browser queries safely no-op
    without exporting arbitrary DOM state.
  - **Files:** `src/pixel_scribe_frontend/browser.gleam`,
    `src/pixel_scribe_frontend/update.gleam`,
    `test/pixel_scribe_frontend/update_test.gleam`.
  - **Verify:** pure command-decision tests plus all Gleam checks.
  - **Depends:** Task 8C.
- [ ] **Task 8E — Prove complete chat behavior in the browser.**
  - **Done when:** routed socket tests assert exact outgoing normalized JSON, no
    optimistic entry, accepted self/peer display, multiline keyboard behavior,
    draft/error handling, deduplication, and reader-preserving scroll.
  - **Files:** `e2e/chat.spec.ts`.
  - **Verify:** focused Chromium chat test, then the full Chromium suite.
  - **Depends:** Task 8D.

**Implementation notes:**

1. Normalize and validate on submit using Task 3's trusted message constructor.
   Invalid input stays in the composer with inline text; valid input sends
   canonical JSON, remains visible, and disables repeat submit while one send is
   in flight.
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

- [ ] No message appears before `message_sent`; accepted self/peer events append
  once by ID, stay in server order, and the visible log remains latest-50 bounded.
- [ ] Empty, over-limit, ninth-line, invalid-control, server invalid-message,
  rate-limit, duplicate event, disconnect-while-pending, and safe-text cases all
  preserve the right draft/UI.
- [ ] Enter, Shift+Enter, and IME composition follow the approved multiline
  policy; the composer remains labeled and scrolling does not drag a reader
  downward.

**Verification:**

- [ ] Update/view tests fail first for send, echo, error, dedup, bound, and draft.
- [ ] `gleam format --check src test`
- [ ] `gleam build`
- [ ] `gleam test`
- [ ] Playwright asserts outgoing JSON and user-visible results through routed WS.
- [ ] `bunx playwright test e2e/chat.spec.ts --project=chromium --reporter=line --workers=1`

**Dependencies:** Task 7 and the updated canonical backend message contract.

**Files likely touched:**

- `src/pixel_scribe_frontend/model.gleam`
- `src/pixel_scribe_frontend/update.gleam`
- `src/pixel_scribe_frontend/view.gleam`
- `test/pixel_scribe_frontend/update_test.gleam`
- `e2e/chat.spec.ts`

**Estimated scope:** Medium, 5 files.

## Task 9: Deliver reconnect, terminal errors, and recovery behavior

**Description:** Wire the proven reconnect/error policy to real timers, socket
generations, and user-visible states. Cover network loss, terminal server errors,
manual retry, new join/snapshot, stale events, and deliberate return to entry.

### Work units

- [ ] **Task 9A — Render and enter reconnecting state.**
  - **Done when:** unexpected loss and `room_unavailable` retain visibly stale
    snapshot/draft, clear only in-flight state, disable send, schedule reconnect,
    and expose immediate retry without replay.
  - **Files:** `src/pixel_scribe_frontend/update.gleam`,
    `src/pixel_scribe_frontend/view.gleam`,
    `test/pixel_scribe_frontend/update_test.gleam`.
  - **Verify:** failing close/error view-transition tests first, then all Gleam
    checks.
  - **Depends:** Task 8E and finalized backend room-unavailable behavior.
- [ ] **Task 9B — Wire retry timers and replacement generations.**
  - **Done when:** timed/immediate retry cancels the prior timer, increments the
    socket generation, stale callbacks cannot win, new room state alone resets
    backoff, and no draft-send command appears automatically.
  - **Files:** `src/pixel_scribe_frontend/reconnect.gleam`,
    `src/pixel_scribe_frontend/update.gleam`,
    `test/pixel_scribe_frontend/update_test.gleam`.
  - **Verify:** fixed-random/timer transition tests plus all Gleam checks.
  - **Depends:** Task 9A.
- [ ] **Task 9C — Implement terminal retry and return-to-entry behavior.**
  - **Done when:** protocol failure and room full enter distinct blocked states,
    explicit retry opens a fresh generation, return-to-entry cancels/closes and
    clears room identity while preserving preference, and late close is ignored.
  - **Files:** `src/pixel_scribe_frontend/update.gleam`,
    `src/pixel_scribe_frontend/view.gleam`,
    `test/pixel_scribe_frontend/update_test.gleam`.
  - **Verify:** focused terminal/manual-action tests plus all Gleam checks.
  - **Depends:** Task 9B.
- [ ] **Task 9D — Prove reconnect and no-replay behavior in the browser.**
  - **Done when:** fixed clock/randomness proves multiple socket generations,
    immediate/timed retries, draft preservation, no automatic send, stale callback
    rejection, new `self_id`, and snapshot replacement without real-time sleeps.
  - **Files:** `e2e/reconnect_errors.spec.ts`.
  - **Verify:** focused Chromium reconnect tests with retained trace on failure.
  - **Depends:** Task 9C.
- [ ] **Task 9E — Prove the full error inventory in the browser.**
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

- [ ] Backoff/jitter, immediate retry, timer cancellation, generation rejection,
  and reset-after-snapshot match the pure policy under browser integration.
- [ ] Reconnect preserves draft without sending it, keeps stale content visibly
  marked, then replaces snapshot/`self_id` and resumes only after `room_state`.
- [ ] Every recoverable and terminal error produces the approved inline/blocked,
  socket, focus, retry, and phase behavior with no automatic error loop.

**Verification:**

- [ ] `gleam format --check src test`
- [ ] `gleam build`
- [ ] `gleam test`
- [ ] Focused Playwright reconnect/error test runs with fixed clock/randomness and
  retained trace on failure.
- [ ] Assert the routed socket receives no `send_message` after reconnection until
  the user submits again.
- [ ] Full Chromium suite passes without real-time sleeps or flaky retries.

**Dependencies:** Task 8 and finalized backend Tasks 7-9 error behavior.

**Files likely touched:**

- `src/pixel_scribe_frontend/reconnect.gleam`
- `src/pixel_scribe_frontend/update.gleam`
- `src/pixel_scribe_frontend/socket.gleam`
- `src/pixel_scribe_frontend/view.gleam`
- `e2e/reconnect_errors.spec.ts`

**Estimated scope:** Medium, 5 files.

## Checkpoint: Real-time UI

- [ ] Two routed browser pages can join, see duplicate-name presence, exchange
  accepted messages, disconnect, and rejoin with a new snapshot/identity.
- [ ] Contract, update, and browser suites cover all errors and race invariants.
- [ ] Draft preservation and absence of optimistic/offline replay are visible in
  browser tests.
- [ ] Format, build, Gleam tests, bundle, and Chromium suite pass.
- [ ] Human reviews real-time UX before canvas work is connected.

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

## Task 11: Deliver the DPR-aware Canvas 2D renderer and approved assets

**Description:** Implement the narrow Canvas effect/FFI, resize and DPR handling,
asset cache/fallback, dirty frame scheduling, and layered scene rendering. Produce
an original or explicitly licensed top-down office/avatar baseline for review.

### Work units

- [ ] **Task 11A — Establish original/licensed assets and provenance.**
  - **Done when:** the source tile/avatar assets have creator, source, license,
    modifications, tile size, and distribution permission recorded; no Pixel
    Agents artwork is copied without an asset-specific compatible license.
  - **Files:** `assets/pixel-art/` and `assets/pixel-art/README.md`.
  - **Verify:** inspect every asset against the provenance record and confirm the
    repository may redistribute it; no renderer code changes in this unit.
  - **Depends:** Task 10D and the real-time UI checkpoint.
- [ ] **Task 11B — Implement canvas initialization, resize, and disposal.**
  - **Done when:** typed effects initialize one fixed canvas renderer, observe its
    content box/DPR, dispatch ready/resize/error, and dispose observers/listeners/
    frames/image references idempotently.
  - **Files:** `src/pixel_scribe_frontend/canvas.gleam`,
    `src/pixel_scribe_frontend/canvas_ffi.mjs`.
  - **Verify:** format/build; review the complete FFI export and handle lifecycle;
    add only boundary tests supported without production test globals.
  - **Depends:** Task 11A.
- [ ] **Task 11C — Render static layers, assets, and fallback geometry.**
  - **Done when:** cached assets draw floor/walls, furniture, Y-sorted avatars,
    names/self accents, and an empty bubble pass; load failure draws a useful
    fallback and reports only safe typed status.
  - **Files:** `src/pixel_scribe_frontend/canvas.gleam`,
    `src/pixel_scribe_frontend/canvas_ffi.mjs`,
    `src/pixel_scribe_frontend/scene.gleam`.
  - **Verify:** all Gleam checks, production bundle, and focused fallback/layer
    browser assertions.
  - **Depends:** Task 11B.
- [ ] **Task 11D — Apply camera crop, DPR scaling, and culling.**
  - **Done when:** world-to-viewport transform precedes DPR scaling, smoothing is
    off, device geometry is rounded, crop/backdrop behavior is correct at edges,
    and offscreen entities are culled without leaving semantic DOM.
  - **Files:** `src/pixel_scribe_frontend/canvas.gleam`,
    `src/pixel_scribe_frontend/canvas_ffi.mjs`, `e2e/canvas.spec.ts`.
  - **Verify:** fixed-seed DPR 1/2 tests for center invariance, resize, peer churn,
    reconnect target, and edge backdrop.
  - **Depends:** Task 11C.
- [ ] **Task 11E — Implement dirty-frame scheduling.**
  - **Done when:** frames run only for init/resize/asset-ready/dirty/active-animation
    causes, delayed delta clamps to 100ms, a static scene reaches zero pending
    frames, and disposal cannot schedule another frame.
  - **Files:** `src/pixel_scribe_frontend/canvas.gleam`,
    `src/pixel_scribe_frontend/canvas_ffi.mjs`, `e2e/canvas.spec.ts`.
  - **Verify:** focused lifecycle browser tests plus all Gleam checks and bundle.
  - **Depends:** Task 11D.
- [ ] **Task 11F — Capture and approve the baseline scene.**
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

- [ ] Approved assets/fallback render a recognizable Pixel-Agents-inspired but
  original office with up to 50 locally placed avatars and documented provenance.
- [ ] Scene remains crisp/aspect-correct at DPR 1/2 and required viewport sizes;
  resize does not accumulate observers/frames or blur coordinates.
- [ ] Self stays centered while the world crop moves after self placement changes;
  peer changes do not move the crop, and edge positions show backdrop rather than
  displacing self. A static scene reaches zero pending animation frames.

**Verification:**

- [ ] Pure coordinate/layer tests pass and FFI has a narrow reviewed export list.
- [ ] `gleam format --check src test`
- [ ] `gleam build`
- [ ] `gleam test`
- [ ] `gleam run -m lustre/dev build`
- [ ] Playwright uses fixed seed/DPR to capture a small set of approved 320px and
  desktop screenshots; checks center invariance, self/peer placement changes,
  reconnect target, resize, edge backdrop, fallback, and no console/page errors.
- [ ] Human approves scene, palette, sprite scale, crowded view, and provenance.

**Dependencies:** Task 10 and real-time UI checkpoint.

**Files likely touched:**

- `src/pixel_scribe_frontend/canvas.gleam`
- `src/pixel_scribe_frontend/canvas_ffi.mjs`
- `src/pixel_scribe_frontend/scene.gleam`
- `assets/pixel-art/` source atlases and provenance
- `e2e/canvas.spec.ts`

**Estimated scope:** Medium, 4 code/test areas plus small reviewed assets.

## Task 12: Connect accepted messages to temporary speech bubbles

**Description:** Add per-participant bubble state and connect unique accepted
`message_sent` events to a six-second, clamped, replaceable, accessible-by-DOM
visual overlay. Reuse the timer/dirty renderer boundaries; do not add chat state
to JavaScript.

### Work units

- [ ] **Task 12A — Add bubble ownership to pure scene/update state.**
  - **Done when:** only unique live accepted messages after room state create a
    sender-ID-owned bubble, newer message replaces it, leave clears it, duplicate
    event does nothing, and snapshot history never creates bubbles.
  - **Files:** `src/pixel_scribe_frontend/scene.gleam`,
    `src/pixel_scribe_frontend/update.gleam`,
    `test/pixel_scribe_frontend/scene_test.gleam`.
  - **Verify:** failing ownership/snapshot/replace/leave tests first, then all
    Gleam checks.
  - **Depends:** Tasks 8E and 11F.
- [ ] **Task 12B — Implement explicit-line bubble layout.**
  - **Done when:** layout splits LF before wrapping, caps at three visual lines,
    adds ellipsis only when truncated, anchors over the avatar, and clamps within
    every tested camera edge while preserving full DOM text.
  - **Files:** `src/pixel_scribe_frontend/scene.gleam`,
    `test/pixel_scribe_frontend/scene_test.gleam`.
  - **Verify:** multiline/wrap/truncate/emoji/edge tests plus all Gleam checks.
  - **Depends:** Task 12A.
- [ ] **Task 12C — Implement bubble timing and reduced motion.**
  - **Done when:** each bubble is fully visible 5s then fades 1s, replacement
    invalidates stale timers, reduced motion removes fade, only the next required
    frame/timer is scheduled, and renderer sleeps after expiry.
  - **Files:** `src/pixel_scribe_frontend/scene.gleam`,
    `src/pixel_scribe_frontend/canvas.gleam`,
    `test/pixel_scribe_frontend/scene_test.gleam`.
  - **Verify:** fixed-clock lifecycle tests plus all Gleam checks.
  - **Depends:** Task 12B.
- [ ] **Task 12D — Prove bubbles in the browser.**
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
   rectangle within the current camera viewport. The full eight-line-capable text
   remains in the DOM.
4. Schedule only the next required expiry/fade frame. Newer bubble invalidates the
   old timer by identity. Reduced-motion keeps the bubble then removes it at
   expiry without opacity animation.
5. Do not announce canvas bubbles separately to assistive technology; the chat
   log's accepted message is the one semantic announcement.

**Acceptance criteria:**

- [ ] Live accepted messages create one correctly owned bubble by sender ID;
  duplicate events do not, newer messages replace, leave clears, and snapshots
  do not replay bubbles.
- [ ] Wrapping, three-line truncation, edge clamping, 5s/1s lifecycle, stale timer,
  reduced-motion, and full-DOM-text invariants have deterministic tests.
- [ ] Renderer sleeps after the final bubble expires and never requires a
  permanent loop for fixed avatars.

**Verification:**

- [ ] Fixed-clock Gleam scene/update tests fail first, then pass.
- [ ] `gleam format --check src test`
- [ ] `gleam build`
- [ ] `gleam test`
- [ ] Playwright routed message produces both full DOM log text and approved
  canvas bubble snapshots before fade, during fade, and after expiry.
- [ ] `bunx playwright test e2e/bubbles.spec.ts --project=chromium --reporter=line --workers=1`

**Dependencies:** Tasks 8 and 11.

**Files likely touched:**

- `src/pixel_scribe_frontend/scene.gleam`
- `src/pixel_scribe_frontend/update.gleam`
- `src/pixel_scribe_frontend/canvas.gleam`
- `test/pixel_scribe_frontend/scene_test.gleam`
- `e2e/bubbles.spec.ts`

**Estimated scope:** Medium, 5 files.

## Checkpoint: Visual direction

- [ ] Human has approved the original/licensed art, palette, scale, and screenshots.
- [ ] Asset provenance is complete and compatible with repository distribution.
- [ ] 0, 1, 20, and 50 avatar scenes render without invalid anchors or overlap.
- [ ] The self avatar remains centered at every tested placement, canvas size,
  DPR, reconnect identity, and world edge; peer churn never pans the camera.
- [ ] Bubble ownership, replacement, clamp, expiry, and reduced motion pass.
- [ ] Canvas failure leaves every essential flow usable through semantic DOM.
- [ ] Format, tests, bundle, and Chromium suite pass.

## Task 13: Finish responsive, keyboard, focus, and accessibility behavior

**Description:** Complete production UI polish across all states and required
viewports. This task fixes accessibility/layout defects exposed by tests; it does
not redesign protocol or add new features.

### Work units

- [ ] **Task 13A — Finish responsive and safe-area layout.**
  - **Done when:** mobile and desktop use the approved rows/columns, `100dvh`,
    safe-area padding, useful canvas/chat minimums, independent log scrolling,
    visible composer, and no body overflow at required widths/orientations.
  - **Files:** `assets/styles.css`, `e2e/responsive.spec.ts`.
  - **Verify:** Chromium checks at 320/768/1024/1440, portrait/landscape where
    relevant, crowded content, reconnect/blocked states, and software-keyboard
    emulation available to the test.
  - **Depends:** visual checkpoint.
- [ ] **Task 13B — Finish deterministic focus and keyboard behavior.**
  - **Done when:** username error, successful join, terminal state, retry, and
    composer focus follow the plan; ordinary presence/chat never steal focus; all
    actions including multiline send remain keyboard-complete.
  - **Files:** `src/pixel_scribe_frontend/view.gleam`,
    `test/pixel_scribe_frontend/view_test.gleam`,
    `e2e/accessibility.spec.ts`.
  - **Verify:** focused view and Chromium keyboard/focus tests plus all Gleam
    checks.
  - **Depends:** Task 13A.
- [ ] **Task 13C — Finish semantic and visual accessibility.**
  - **Done when:** forms/lists/log/status/canvas fallback, busy/disabled states,
    visible focus, non-color status, 4.5:1 text contrast, 200% text zoom, long
    content, and live-region restraint satisfy the parent criteria.
  - **Files:** `src/pixel_scribe_frontend/view.gleam`, `assets/styles.css`,
    `test/pixel_scribe_frontend/view_test.gleam`.
  - **Verify:** view tests plus all Gleam checks and production bundle.
  - **Depends:** Task 13B.
- [ ] **Task 13D — Run unsuppressed axe state coverage.**
  - **Done when:** username, joined, reconnecting, protocol-failure, room-full,
    and room-unavailable states have WCAG A/AA scans with no disabled rules or
    excluded application subtree.
  - **Files:** `e2e/accessibility.spec.ts`,
    `e2e/support/accessibility.ts` only for reusable state-neutral helpers.
  - **Verify:** focused Chromium accessibility suite.
  - **Depends:** Task 13C.
- [ ] **Task 13E — Complete cross-browser and manual accessibility evidence.**
  - **Done when:** Chromium/Firefox/WebKit pass and keyboard-only, 200% zoom,
    reduced-motion, screen-reader, canvas-disabled, and responsive smoke results
    are recorded without product changes hidden in this verification unit.
  - **Files:** `tasks/todo.md` (evidence checkboxes only). Implementation defects
    discovered here require a separately reviewed corrective unit.
  - **Verify:** full three-browser matrix and the listed manual checks.
  - **Depends:** Task 13D.

**Implementation notes:**

1. Mobile `<768px`: canvas top, chat bottom, useful minimums, composer visible.
   Desktop: `100dvh`, `minmax(0,1fr)` canvas and `22rem` rail. Add safe-area
   padding and independent chat scrolling without body overflow.
2. Verify 320, 768, 1024, and 1440 CSS px, portrait/landscape where applicable,
   browser zoom/text enlargement, long Unicode names/messages, 50 participants,
   empty/loading/reconnecting/blocked states, self-centered camera crop, and
   software-keyboard behavior.
3. Implement deliberate focus: username error -> username; first successful join
   -> composer; blocked state -> status/primary retry; manual retry does not lose
   keyboard context. Ordinary chat/presence never steals focus.
4. Use semantic form/list/log/status markup, visible focus, meaningful canvas
   fallback/name, `aria-busy`/disabled states, text plus color for status, and
   contrast meeting WCAG AA. Avoid excessive live-region announcements.
5. Run axe in username, joined, reconnecting, and each terminal state. Do not fix
   automated failures by disabling a rule or excluding the app without review.

**Acceptance criteria:**

- [ ] Every product state is keyboard-complete, focus-correct, text-safe, and has
  no automatically detectable WCAG A/AA violation.
- [ ] Required viewport/orientation/crowded-content tests show no clipped controls,
  hidden composer, body horizontal scroll, unusable canvas, or safe-area collision.
- [ ] Canvas remains supplementary: disabling/removing it leaves join, status,
  participants, errors, chat history, and composer understandable and usable.

**Verification:**

- [ ] View tests cover roles, labels, descriptions, disabled/busy, live regions,
  focus targets, duplicate/long content, and canvas fallback.
- [ ] `gleam format --check src test`
- [ ] `gleam build`
- [ ] `gleam test`
- [ ] Playwright responsive/accessibility suites pass in Chromium.
- [ ] Install and run Firefox/WebKit projects for the frontend release matrix.
- [ ] Manual keyboard-only, 200% text zoom, reduced-motion, and screen-reader
  smoke checks are recorded.

**Dependencies:** Tasks 7-12 and visual checkpoint.

**Files likely touched:**

- `src/pixel_scribe_frontend/view.gleam`
- `assets/styles.css`
- `test/pixel_scribe_frontend/view_test.gleam`
- `e2e/responsive.spec.ts`
- `e2e/accessibility.spec.ts`

**Estimated scope:** Medium, 5 files.

## Task 14: Add reproducible staging and container delivery

**Description:** Build to ignored `dist/`, safely stage a clean copy into backend
`priv/public`, remove superseded placeholders, and add a production container
frontend stage. Generated output remains uncommitted.

### Work units

- [ ] **Task 14A — Implement the safe staging script.**
  - **Done when:** one repository-root command resolves fixed paths, validates
    source/target markers, rejects symlinks/unexpected targets, builds, verifies
    `dist/index.html`, cleans only exact backend `priv/public`, and copies all
    output with fail-fast behavior.
  - **Files:** `../scripts/stage_frontend.sh`.
  - **Verify:** shell syntax check; run from clean artifacts twice; compare exact
    `dist/` and target trees; deliberately test safe refusal cases without using
    a broad destructive target.
  - **Depends:** Task 13E and coordinated backend static-delivery target.
- [ ] **Task 14B — Align generated-output policy and delivery docs.**
  - **Done when:** frontend build/staged output is ignored, lock/source files stay
    tracked, superseded placeholder policy is explicit, and docs give exact dev,
    test, staging, and same-origin commands.
  - **Files:** `../.gitignore`, `README.md`.
  - **Verify:** `jj status`; inspect ignore behavior and documentation commands;
    no generated bundle is tracked.
  - **Depends:** Task 14A.
- [ ] **Task 14C — Add the reproducible frontend container stage.**
  - **Done when:** Docker builds from locked Gleam/Bun inputs, stages only `dist/`
    into the backend build before shipment export, and the runtime image contains
    no Bun/Node/Playwright/source tree.
  - **Files:** `../Dockerfile`.
  - **Verify:** clean container build; inspect runtime contents and served `/` plus
    a known asset; no browser installation occurs.
  - **Depends:** Task 14B and backend static handler Task 10.
- [ ] **Task 14D — Prove staging and shipment integration.**
  - **Done when:** repeated staging leaves no stale file, backend static tests pass,
    the container serves the complete app, unknown paths remain 404, and status
    shows no unintentionally tracked generated asset.
  - **Files:** `tasks/todo.md` (evidence checkboxes only). Any implementation
    defect requires a separately reviewed corrective unit in its owning package.
  - **Verify:** all frontend checks, backend static tests, staging twice, container
    smoke, and `jj status`/`jj diff`.
  - **Depends:** Task 14C.

**Implementation notes:**

1. Add one repository-level script with no ambiguous current-directory behavior.
   Resolve repo/source/target paths, require expected marker directories, reject
   symlink/unexpected targets, build frontend, verify `dist/index.html`, clean only
   the exact backend public target, and copy the complete output.
2. The script must fail on any build/copy error and must not use `$HOME`, broad
   globs, workspace-root deletion, or an unresolved environment variable as a
   destructive target.
3. Remove tracked placeholder public pages when coordinated with the backend.
   Ignore generated staged contents and preserve a documented way to recreate
   them. Do not commit a generated bundle.
4. Extend the Dockerfile with a pinned/reproducible frontend build stage using the
   locked Gleam/Bun inputs, then copy only `dist/` into the backend build before
   the Erlang shipment export. Production image contains no Node/Bun/Playwright or
   source tree.
5. Update development/build docs with frontend-only dev, mocked browser test,
   staging, backend-served same-origin, and container commands.

**Acceptance criteria:**

- [ ] One command from repository root creates a clean, complete backend public
  tree from source/locks and cannot clean outside the validated explicit target.
- [ ] A clean Docker build compiles the frontend before backend shipment and the
  runtime image contains/serves assets without frontend build/test tooling.
- [ ] `dist/` and staged generated public files remain uncommitted/reproducible;
  placeholder pages and docs no longer describe the old state.

**Verification:**

- [ ] Run staging from a clean frontend artifact state; inspect the exact target
  tree and compare it to `dist/`.
- [ ] Run the staging command twice and verify no stale/duplicate file survives.
- [ ] All frontend format/build/test/browser checks pass before staging.
- [ ] Backend static handler tests pass against the staged tree once backend Task
  10 exists.
- [ ] Build and smoke-test the container without installing Playwright browsers.
- [ ] `jj status` shows no generated bundle/staged asset unintentionally tracked.

**Dependencies:** Task 13 and coordinated backend static-delivery work.

**Files likely touched:**

- `../scripts/stage_frontend.sh`
- `../Dockerfile`
- `../.gitignore`
- `README.md`
- `../pixel_scribe_backend/priv/public/` placeholder/generated policy

**Estimated scope:** Medium, 4 files plus one explicit generated-target policy.

## Task 15: Run real-backend MVP acceptance and align documentation

**Description:** Replace routed WebSocket fixtures with a separate same-origin
acceptance project against the running backend, use two independent browser
contexts, and prove the delivered MVP. Keep mock tests because they provide
deterministic edge coverage.

### Work units

- [ ] **Task 15A — Add the real-backend acceptance harness.**
  - **Done when:** a separate Playwright project stages the frontend, starts the
    backend on a dedicated port, waits for `/healthz`, uses the backend origin,
    and never routes/intercepts WebSockets.
  - **Files:** `playwright.config.ts`, `e2e/mvp_backend.spec.ts`.
  - **Verify:** list/start the project, prove health readiness and clean shutdown,
    and assert no `page.routeWebSocket` in this project.
  - **Depends:** Task 14D and backend Tasks 7-10.
- [ ] **Task 15B — Prove two-client presence and chat.**
  - **Done when:** isolated contexts with duplicate labels receive distinct self
    identity, exact presence join/leave, accepted self/peer chat, bounded history,
    multiline DOM rendering, and correctly owned bubbles.
  - **Files:** `e2e/mvp_backend.spec.ts`.
  - **Verify:** focused real-backend two-client test.
  - **Depends:** Task 15A.
- [ ] **Task 15C — Prove validation, rate, capacity, and recovery.**
  - **Done when:** invalid username/message, newline normalization, eight-line
    limit, rate limiting, room capacity where practical, unexpected disconnect,
    reconnect/new identity, snapshot replacement, draft preservation, and no
    replay match the canonical contract.
  - **Files:** `e2e/mvp_backend.spec.ts`; destructive/failure injection remains in
    backend-owned approved fixtures.
  - **Verify:** focused real-backend validation/recovery tests without routed WS.
  - **Depends:** Task 15B.
- [ ] **Task 15D — Prove HTTP, security, and logging behavior.**
  - **Done when:** `/`, known asset, `/healthz`, missing/unknown 404, same-origin
    WebSocket, production security headers, origin policy, and absence of
    cookie/message/raw-payload logging all have evidence.
  - **Files:** `e2e/mvp_backend.spec.ts`.
  - **Verify:** focused HTTP/security acceptance plus backend tests.
  - **Depends:** Task 15C.
- [ ] **Task 15E — Align all user-facing documentation.**
  - **Done when:** frontend/backend/root READMEs, backend spec, task statuses,
    commands, multiline limits, error phases, local avatars, temporary history,
    and deferred features describe the implementation identically.
  - **Files:** `README.md`, `../README.md`,
    `../pixel_scribe_backend/docs/mvp-backend-spec.md`.
  - **Verify:** search for stale event names/limits/single-line behavior; compare
    protocol/error tables; review the documentation-only diff.
  - **Depends:** Task 15D.
- [ ] **Task 15F — Run final automated and manual acceptance.**
  - **Done when:** all frontend/backend/mock/real suites, three browser projects,
    staging/container checks, and manual two-browser keyboard/responsive/reconnect
    smoke pass with recorded evidence and no generated/unlicensed artifact.
  - **Files:** `tasks/todo.md` (evidence checkboxes only). Any implementation
    defect becomes a separately reviewed corrective unit.
  - **Verify:** every command under the parent verification section and every
    item in the final review gate.
  - **Depends:** Task 15E.

**Implementation notes:**

1. Gate on backend Tasks 7-10. Stage the frontend, start the backend on a dedicated
   test port, wait on `/healthz`, and navigate through the backend origin. Do not
   use `page.routeWebSocket` in this project.
2. Use two isolated contexts to join `default`, including a duplicate-username
   case; assert snapshot, self distinction, join/leave presence, accepted chat,
   self echo, message history, and speech bubbles through user-visible behavior.
3. Exercise invalid username/message, rate limit, room capacity where practical,
   unexpected disconnect/reconnect, new `self_id`, snapshot replacement, draft
   preservation, no offline replay, and backend restart/history-loss messaging.
   Keep destructive/failure injection in backend-owned integration fixtures.
4. Verify production response headers, same-origin WebSocket, `/`, known asset,
   missing asset/unknown route 404, and no cookie/message/raw-payload logging.
5. Align frontend/backend/root READMEs, backend spec, task status, commands,
   limits, temporary chat semantics, client-local avatars, and deferred features.

**Acceptance criteria:**

- [ ] Two real browser contexts can join, remain distinct with duplicate labels,
  see presence, exchange accepted chat/bubbles, leave, reconnect, and replace state.
- [ ] Production-origin HTTP/WebSocket, errors, validation, rate/recovery, cookie,
  accessibility, responsive, and static-delivery behavior match the approved docs.
- [ ] All mock/unit/real suites and manual acceptance pass, and every user-facing
  document accurately describes implemented behavior and non-goals.

**Verification:**

- [ ] Frontend: `gleam format --check src test`
- [ ] Frontend: `gleam build`
- [ ] Frontend: `gleam test`
- [ ] Frontend: `gleam run -m lustre/dev build`
- [ ] Frontend: full Playwright Chromium/Firefox/WebKit matrix.
- [ ] Backend: `gleam format --check src test`, `gleam build`, and `gleam test`.
- [ ] Repository staging command succeeds from clean artifacts.
- [ ] Same-origin real-backend Playwright project passes without WS routing.
- [ ] Manual two-browser keyboard/responsive/reconnect smoke check passes.
- [ ] Review all docs and `jj diff`; no generated output or unlicensed asset is
  included.

**Dependencies:** Task 14 and backend Tasks 7-10.

**Files likely touched:**

- `e2e/mvp_backend.spec.ts`
- `playwright.config.ts`
- `README.md`
- `../README.md`
- `../pixel_scribe_backend/docs/mvp-backend-spec.md`

**Estimated scope:** Medium, 5 files.

## Final Review Gate

- [ ] Every task acceptance criterion and checkpoint is checked with evidence.
- [ ] The frontend never keys identity, placement, message ownership, or bubbles
  by username.
- [ ] The camera targets only `self_id`, keeps that avatar centered, and never
  introduces synchronized coordinates, manual pan, or zoom into the MVP.
- [ ] The frontend never renders optimistic/offline messages or promises durable
  chat/session restoration.
- [ ] The WebSocket contract, limits, errors, and fixtures match the canonical
  backend specification.
- [ ] Essential behavior is semantic DOM, keyboard usable, safe as text, and
  responsive to 320px; Canvas remains supplementary.
- [ ] Renderer/browser/socket FFI boundaries are narrow, disposed, and tested;
  static scenes do not run continuously.
- [ ] No authentication, alternate room, movement, editor, game engine, Wasm,
  media, or new protocol field entered scope.
- [ ] Full Gleam, browser, staging, container, and real-backend checks pass.
- [ ] Code, security, accessibility, and simplification reviews are complete.
- [ ] Human approves the MVP for merge/release.
