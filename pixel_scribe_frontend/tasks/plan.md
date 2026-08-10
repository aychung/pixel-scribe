# Implementation Plan: Pixel Scribe Frontend MVP

## Status

Approved on 2026-08-09. Task 0 and Task 1 are complete as of 2026-08-10.
This document plans the remaining frontend implementation only. The final
same-origin acceptance task remains gated on backend Tasks 7-10.

## Source of Truth and Precedence

Use these sources in this order:

1. [`../AGENTS.md`](../AGENTS.md) for repository and implementation rules.
2. [`../../pixel_scribe_backend/docs/mvp-backend-spec.md`](../../pixel_scribe_backend/docs/mvp-backend-spec.md)
   for the public HTTP/WebSocket contract.
3. [`../README.md`](../README.md) for frontend UX, layout, and architecture.
4. This plan and [`todo.md`](todo.md) for execution order and task-level detail.
5. The repository-root README only where it does not conflict with the canonical
   frontend or backend documents.

If the backend implementation changes event fields, validation, error
recoverability, or socket-close behavior, stop and reconcile the canonical
backend specification, protocol fixtures, this plan, and the frontend codecs
before continuing. Do not infer a new contract from observed behavior alone.

## Objective

Build a browser-only Lustre SPA that lets a visitor reuse or enter a display
username, join the built-in `default` office over the same-origin `/ws` JSON
WebSocket, see presence and bounded recent chat, exchange plain-text messages,
and view each participant as a locally placed avatar in a responsive pixel-art
office whose logical world is larger than the canvas viewport. A frontend-local
camera keeps the current client's avatar centered while the office moves beneath
it. Accepted messages also appear temporarily as speech bubbles over their
sender's avatar.

The frontend owns visual placement. Avatar coordinates never enter the public
protocol, are never sent to the backend, and may differ between clients.

## Confirmed Product and Engineering Decisions

- Use `lustre.application` and `lustre.start` for one client-side SPA. Do not use
  server components, a second UI framework, a game engine, or Wasm.
- Use Canvas 2D behind a narrow renderer boundary. HTML remains authoritative for
  forms, connection status, participant names/count, chat history, errors, and
  all interactive controls.
- Use Pixel Agents as architectural and visual inspiration, not as code to port.
  Borrow its logical pixel grid, layered renderer, device-pixel-aware scaling,
  local avatar state, camera transform, and asset caching. Do not copy its
  editor, pathfinding, camera controls, seats, pets, movement, transport coupling,
  large mutable state object, or continuously running loop.
- Start with a `16px` logical tile, a `96 x 64` tile office (`1536 x 1024`
  logical pixels), `50` curated non-overlapping avatar anchors, and fixed avatars.
  The world size is asset metadata rather than the canvas size and can change
  after the visual checkpoint without changing application or protocol logic.
- Derive a local camera from the current canvas viewport and `self_id` avatar.
  Keep that avatar's visual center exactly at the viewport center, move the office
  in the opposite direction when the self placement changes, and fill any
  out-of-world view with the scene backdrop instead of clamping the camera away
  from the avatar. Other participants joining/leaving must not move the camera.
  The MVP has no easing, manual panning, or zoom control.
- Generate one per-page placement seed in the browser. Preserve positions for
  surviving connection IDs, allocate new IDs to free anchors using the seed and
  deterministic probing, and free anchors on leave. Tests inject a fixed seed.
- Show one speech bubble per participant. A newer accepted message replaces that
  participant's current bubble. The working lifetime is `6,000ms`, with opacity
  fading only during the final `1,000ms`. Bubble text is clamped and visually
  truncated to three lines; the full message always remains in the DOM chat log.
- Support multiline chat with a textarea. Allow LF; reject CR, `U+2028`,
  `U+2029`, every other C0/C1 control, and DEL; trim; then require `1-500`
  Unicode grapheme clusters, counting each LF. LF is the only control retained
  in the trusted message value. Enter sends, Shift+Enter inserts LF, and Enter
  never sends during IME composition.
- Before sending either `join_room` or `send_message`, serialize the complete
  JSON object and measure the final UTF-8 text frame. Accept `8,192` bytes and
  reject `8,193` bytes (or larger) locally; keep the username/draft with inline
  feedback and emit no frame, preventing the backend's terminal `invalid_event`.
- Store the username preference in a frontend-written
  `pixel_scribe_username` cookie for `180` days with `Path=/`,
  `SameSite=Strict`, no `Domain`, and `Secure` when the page is HTTPS. It cannot
  be `HttpOnly` because browser JavaScript owns it. It is a preference, never
  identity or authorization.
- Reconnect unexpected network failures with capped exponential backoff:
  `500ms`, `1s`, `2s`, `4s`, `8s`, `16s`, then `30s`, with `+/-25%` jitter. Reset
  the attempt counter only after a valid `room_state`.
- Preserve the current draft and last room view while reconnecting, visibly mark
  that view stale, disable sending, and never queue or replay an offline send.
  Replace the snapshot, `self_id`, and scene reconciliation input after the new
  `room_state`.
- Add Playwright and `@axe-core/playwright` as development-only browser-test
  dependencies. Use Playwright's CLI non-interactively by default and intercept
  `/ws` with `page.routeWebSocket` before navigation for deterministic frontend
  tests. Keep a separate suite for the real backend.
- Build with Lustre's official dev tools into ignored
  `pixel_scribe_frontend/dist/`. A repository script validates explicit paths,
  cleans only the frontend staging target in `pixel_scribe_backend/priv/public`,
  and copies the complete build. Generated bundles remain uncommitted.

## Explicit Non-Goals

- Authentication, accounts, permissions, or treating the username cookie as a
  session.
- More than the one hard-coded `default` room or any room picker.
- Synchronized avatar coordinates, movement, pathfinding, collision simulation,
  seating, office editing, manual camera panning, zoom controls, camera easing,
  or avatar customization.
- Durable or offline chat, delivery acknowledgements, automatic resend, message
  markup, media, voice, video, or screen sharing.
- A second bundler, Tailwind, a state-management library, or a game framework.
- Wasm or premature renderer optimization without representative profiling.

## Architecture

### Module boundaries

```text
pixel_scribe_frontend.gleam
  Starts the Lustre application on #app.

model.gleam + update.gleam + view.gleam
  Explicit application Model, Msg, deterministic transitions, commands, and DOM.

domain.gleam + validation.gleam + protocol.gleam
  Opaque IDs, trusted frontend values, client encoders, server decoders, fixtures.

socket.gleam + socket_ffi.mjs
  Native WebSocket lifecycle and text-frame I/O only.

browser.gleam + browser_ffi.mjs
  Cookie preference, secure seed/random value, timers, focus, and small DOM hooks.

scene.gleam + placement.gleam + camera.gleam
  Pure world/viewport state, local anchors, self-centered camera, bubbles, layers.

canvas.gleam + canvas_ffi.mjs
  ResizeObserver, DPR-aware backing store, asset cache, rAF, Canvas 2D drawing.
```

The FFI owns opaque browser handles such as the WebSocket, canvas context,
ResizeObserver, decoded images, timers, and animation-frame ID. The Gleam model
owns all user-visible state. No FFI module may mutate Lustre-rendered DOM, log
payloads/user content, decide protocol transitions, or call another subsystem's
FFI directly.

### Application state

Keep state explicit rather than encoding behavior in boolean combinations:

```text
ConnectionPhase
├── ChoosingUsername
├── Connecting(generation, attempt)
├── AwaitingRoomState(generation, attempt)
├── Joined(generation, self_id)
├── WaitingToReconnect(next_generation, attempt, delay_ms)
└── Blocked(reason)

Model
├── username_input / username_preference
├── phase / socket_generation
├── room_snapshot? (room_id, self_id, participants, messages)
├── draft / send_in_flight
├── field_feedback / connection_feedback
├── reconnect_attempt / timer identity
├── rate_limit_until?
├── scene (placement seed, avatars, bubbles, world and camera viewport state)
└── chat scroll/focus requests expressed as commands
```

Use the opaque connection ID as the participant key, the opaque message ID as
the message key, and `self_id` for authorship. Never key by username. Keep the
visible message list bounded to the latest `50` accepted messages to match the
server snapshot limit and bound browser memory.

Every socket callback carries a monotonically increasing generation. Ignore
callbacks and timers from stale generations so a late close/message cannot tear
down a replacement socket.

### Deterministic transition and effect pattern

`update` must remain easy to unit-test. Represent external work as a small closed
set of commands (open/close socket, send text frame, persist preference, schedule
or cancel timer, focus/scroll, render/resize/dispose canvas). The pure transition
returns the next model and commands; a thin interpreter converts commands to
Lustre `Effect(Msg)` values and batches them. Do not hide state transitions in
JavaScript callbacks.

### Join and live-event invariants

1. Submitting a valid username preflights the final `join_room` frame. If it is
   oversized, keep the username with inline feedback and open no socket;
   otherwise store the normalized preference, open one new socket generation,
   and enter `Connecting`.
2. `SocketOpened` sends exactly one `join_room` for `default` for that generation
   and enters `AwaitingRoomState`.
3. Chat remains disabled until a valid matching `room_state` supplies `self_id`.
4. `room_state` replaces participants and messages, deduplicates messages by ID,
   resets reconnect attempts, reconciles local avatar placement, and retargets
   the camera to the new `self_id` avatar.
5. `user_joined` upserts only by `connection_id`; `user_left` removes only that
   ID and its local bubble/anchor.
6. `message_sent` appends once by `message_id`, including self messages, and
   creates/replaces the sender's bubble. No optimistic message is rendered.
7. Allow one chat send in flight. Keep the visible draft until the corresponding
   self `message_sent` or a structured error. On disconnect, clear only the
   in-flight marker and keep the draft; never send it automatically after join.
8. A room-scoped event for another room, a malformed known event, or a broken
   required invariant is a protocol failure. Unknown future event types are
   safely ignored.

### Error policy

| Error | Frontend behavior |
| --- | --- |
| `invalid_username` | Keep socket open, return to/focus the username field, show inline feedback, allow another join only if the finalized backend phase permits it. |
| `invalid_message` | Keep socket and joined state, keep draft, clear in-flight state, show composer feedback. |
| Oversized final client frame | Keep the username or draft, show inline feedback, and emit no `join_room`/`send_message` frame; this is a local validation failure, not a backend `invalid_event`. |
| `rate_limited` | Keep draft/socket, clear in-flight state, disable send for one second, announce feedback. |
| `join_required` | Keep socket unjoined and chat disabled; show protocol feedback without an automatic send loop. |
| `already_joined` | Preserve the current joined identity and snapshot; report the anomaly without another join. |
| `invalid_room_id` / `room_not_found` | Since MVP has no room picker, stop this attempt and show the built-in office as unavailable with explicit retry. |
| `room_mismatch` | Keep joined state, reject the affected action, show client-defect feedback, never change rooms. |
| `invalid_event` or malformed server data | Close deliberately, enter blocked protocol-failure UI, require explicit retry. |
| `room_full` | Enter blocked join UI with username prefilled and an explicit retry that opens a new socket. |
| `room_unavailable` | Close/accept server close and enter automatic reconnect; also expose an immediate retry control. |
| Unexpected error/close | Enter automatic reconnect unless the user deliberately left or a terminal policy already owns the close. |

Task 6 must compare this table with the backend's finalized Task 7 error/close
matrix. Any difference is a documentation decision, not an implementation guess.

### Reconnect calculation

Keep the calculation pure and injectable:

```text
base_ms = min(500 * 2^attempt, 30_000)
jitter_factor = 0.75 + (random_unit * 0.50)  // random_unit in [0, 1]
delay_ms = round(base_ms * jitter_factor)
```

Cancel the current retry timer on manual retry, successful `room_state`, return
to username entry, or app disposal. A socket `open` does not reset backoff because
join can still fail; only `room_state` proves recovery.

### Scene and renderer

- Separate world pixels, CSS pixels, and backing-store/device pixels in names and
  types. Never pass an unlabeled coordinate between layers.
- Observe the canvas container. Set the backing store from its CSS size and the
  current device pixel ratio; recompute the camera viewport on resize/DPR change.
- Treat the `1536 x 1024` office as a world larger than the viewport. At the
  baseline zoom, one logical world pixel maps to one CSS pixel. Round the logical
  viewport extent down to even dimensions when necessary so the self avatar can
  land on an integral center; use at most a one-pixel backdrop gutter.
- Compute camera origin from the self avatar's visual center minus half the
  viewport extent. Do not clamp the camera: when its crop extends beyond the
  office, draw the scene backdrop there so the current client remains exactly
  centered. On reconnect, immediately retarget to the avatar for the new
  `self_id`; changes to other avatars do not affect the camera.
- Transform every world-space draw through the camera before DPR scaling. Use
  integer device-pixel coordinates wherever possible, disable image smoothing,
  clip to the viewport, and keep logical entity coordinates integral.
- Define at least `50` curated walkable anchors that do not intersect furniture
  and leave room for clamped bubbles. Seeded hash plus linear probing selects a
  free anchor; reconciliation first retains still-present IDs.
- Draw in stable passes: static floor/walls, furniture, avatars sorted by
  bottom-anchor Y, name/self/status accents, then speech bubbles.
- Load an original or explicitly licensed tile/avatar atlas once, cache decoded
  images/derived variants, and provide a visible fallback avatar/scene on load
  failure. Record provenance in `assets/pixel-art/README.md`; do not assume the
  Pixel Agents artwork is reusable because its application code is MIT.
- Request a frame only when the scene is dirty or a bubble is fading. Clamp a
  delayed animation delta to `100ms`, cancel frames and observers on disposal,
  and honor `prefers-reduced-motion` by removing the fade transition.
- Canvas is non-interactive in the MVP. Do not add pointer handlers, hit testing,
  selection, manual camera controls, or state-changing test globals.

### Responsive and accessible DOM

- Mobile first. Under `768px`, use canvas then chat as rows; at/above `768px`,
  use `minmax(0, 1fr)` plus a `22rem` chat rail. Keep the rail width as a CSS
  custom property and use the native media query for the breakpoint.
- Use `100dvh`, safe-area insets, independent chat scrolling, and a composer that
  remains visible with mobile browser chrome/software keyboard.
- Username and composer use real labels and native controls. Status uses a
  restrained polite live region; the message list uses appropriate log semantics;
  participants are a semantic list. Mark the current connection as “You”.
- Canvas has a concise accessible name and fallback text, but does not duplicate
  every chat/presence update to assistive technology. Complete equivalent content
  is already present in the DOM.
- Manage focus after validation failure, successful join, terminal state, and
  explicit retry. Never steal focus for ordinary presence/message events.
- Verify keyboard-only operation, visible focus, text zoom, 4.5:1 normal-text
  contrast, status not conveyed by color alone, reduced motion, and layouts at
  `320`, `768`, `1024`, and `1440` CSS pixels in relevant orientations.

## Testing Strategy

### Gleam tests

- Protocol fixtures for every server event and error plus malformed, missing,
  wrong-type, additive-field, unknown-event, Unicode, LF, rejected newline/control,
  and grapheme-limit cases.
- Pure transition tests for every connection phase, generation race, error path,
  draft/in-flight behavior, deduplication, snapshot replacement, and reconnect
  timer command.
- Pure scene tests for seeded unique allocation, retention/release, 50-user
  capacity, self-camera targeting, layer order, coordinate transforms, bubble
  replace/expire/fade, wrapping/truncation, and viewport clamping.
- Lustre view queries/simulation for labels, roles, enabled/disabled controls,
  live-region content, duplicate usernames, and safe text rendering.

### Playwright tests

- Add a `/ws` route before `page.goto` and emulate exact JSON frames. Assert only
  user-visible DOM outcomes and a few stable canvas screenshots; never mutate the
  production model from tests.
- Cover join, initial snapshot, duplicate names, presence changes, accepted/self
  chat, validation/rate errors, terminal errors, disconnect/reconnect, stale
  generations, new `self_id`, draft preservation, no offline replay, cookie
  prefill, oversized final-frame rejection without a socket send, keyboard/focus,
  responsive layout, resize/DPR, self-centered camera, bubbles, and no console
  errors.
- Use fixed placement/random values, Playwright's controllable clock, reduced
  motion, and fixed `deviceScaleFactor` for deterministic timing/screenshots.
- Run axe WCAG A/AA scans in username, joined, reconnecting, and terminal states;
  automated scanning supplements rather than replaces keyboard/manual checks.
- Run Chromium for every task. Run Chromium, Firefox, and WebKit at the final
  frontend checkpoint and against the real backend before release.

### Playwright CLI contract for Codex and CI

Run from `pixel_scribe_frontend/`:

```sh
bun install --frozen-lockfile
bunx playwright install chromium
bunx playwright test --project=chromium --reporter=line --workers=1
```

For a focused failure:

```sh
bunx playwright test e2e/<file>.spec.ts -g "<test name>" \
  --project=chromium --reporter=line --workers=1 --trace=retain-on-failure
```

Codex should use the non-interactive CLI, read `test-results/` traces/screenshots,
and report the failing file/test. Do not default to `--ui`, `--debug`, headed
browsers, or `show-report`; those are human/interactive diagnostics and may
require GUI approval. Browser installation is an explicit environment setup step,
not something hidden inside the normal test command.

## Build and Delivery Contract

1. `gleam run -m lustre/dev build` produces the complete frontend in ignored
   `pixel_scribe_frontend/dist/`; assets are referenced from `/`, not `/assets/`.
2. A repository-level script resolves and validates the exact source and target,
   refuses symlink/unexpected paths, cleans only
   `pixel_scribe_backend/priv/public`, and copies the complete `dist/` tree.
3. Placeholder backend public files are removed when the delivery task is
   approved. Neither `dist/` nor staged generated public output is committed.
4. The Docker build gains a reproducible frontend stage and copies its output
   into the backend shipment before export. Do not download browsers in the
   production image.
5. Full-stack development/acceptance uses the backend-served same origin. Lustre's
   dev server is sufficient for UI work with Playwright-routed `/ws`; do not add
   an undocumented production WebSocket URL override.

## Dependency Graph

```text
Task 0 Toolchain
├── Task 1 Lustre shell
│   └── Task 2 Test harness
├── Task 3 Protocol + validation
└── Task 4 State machine + reconnect policy
    └── Task 5 Browser preferences/effects

Tasks 1-5
└── Task 6 Join snapshot slice
    └── Task 7 Presence workspace
        ├── Task 8 Chat slice
        │   └── Task 9 Recovery/error slice
        └── Task 10 Scene + camera + placement
            └── Task 11 Canvas renderer/assets

Tasks 8 + 11
└── Task 12 Speech bubbles

Tasks 7-12
└── Task 13 Responsive/accessibility polish
    └── Task 14 Build/staging delivery

Frontend Task 14 + backend Tasks 7-10
└── Task 15 Real-backend acceptance and documentation
```

## Execution Granularity

The numbered Tasks 0-15 below are macro milestones. They are not single agent
assignments. [`todo.md`](todo.md) divides them into lettered XS/S work units; one
agent turn implements exactly one unchecked work unit, runs that unit's focused
verification, inspects the diff, records evidence, and stops. A macro task is
complete only after all of its work units and parent acceptance criteria pass.

Work-unit ranges are fixed so dependencies remain easy to reference:

| Macro task | Work units |
| --- | --- |
| Task 0 | 0A-0C |
| Task 1 | 1A-1C |
| Task 2 | 2A-2C |
| Task 3 | 3A-3D |
| Task 4 | 4A-4F |
| Task 5 | 5A-5E |
| Task 6 | 6A-6E |
| Task 7 | 7A-7D |
| Task 8 | 8A-8E |
| Task 9 | 9A-9E |
| Task 10 | 10A-10D |
| Task 11 | 11A-11F |
| Task 12 | 12A-12D |
| Task 13 | 13A-13E |
| Task 14 | 14A-14D |
| Task 15 | 15A-15F |

The work-unit file list is an edit boundary, not a prediction. If implementation
requires another production file, stop and revise the checklist through review
instead of expanding scope silently. Generated lockfiles are allowed only when
the unit names the package-manager command that produces them.

## Task List

### Phase 1: Reproducible foundation

- [x] Task 0 (0A-0C): Lock the frontend toolchain and artifact policy.
  - [x] 0A: Resolve Gleam dependencies.
  - [x] 0B: Resolve browser-test dependencies and scripts.
  - [x] 0C: Configure Lustre output and artifact ignores.
- [x] Task 1 (1A-1C): Bootstrap the explicit Lustre SPA shell.
  - [x] 1A: Create the explicit MVU skeleton.
  - [x] 1B: Render the semantic username form.
  - [x] 1C: Style the responsive shell.
- [ ] Task 2 (2A-2C): Establish the Gleam and Playwright test harnesses.
- [ ] Task 3 (3A-3D): Implement trusted values, validation, and protocol codecs.
- [ ] Task 4 (4A-4F): Implement the deterministic state machine and backoff.
- [ ] Task 5 (5A-5E): Add browser preference and small DOM effects.

### Checkpoint: Foundation

- [ ] Format, Gleam build/tests, production bundle, and shell Playwright test pass.
- [ ] Protocol fixtures match the canonical backend specification.
- [ ] No browser handle or untrusted dynamic value enters the application model.
- [ ] Human reviews the state/error tables before network integration.

### Phase 2: Real-time vertical slices

- [ ] Task 6 (6A-6E): Deliver joining through native WebSocket.
- [ ] Task 7 (7A-7D): Deliver the joined presence/status workspace.
- [ ] Task 8 (8A-8E): Deliver accepted chat without optimistic rendering.
- [ ] Task 9 (9A-9E): Deliver reconnect, terminal errors, and recovery.

### Checkpoint: Real-time UI

- [ ] Mocked WebSocket tests prove join, presence, chat, errors, and reconnect.
- [ ] Draft preservation, snapshot replacement, ID deduplication, and no replay
  are explicit passing tests.
- [ ] Format, build, Gleam tests, bundle, and Chromium Playwright suite pass.

### Phase 3: Pixel office

- [ ] Task 10 (10A-10D): Define the pure world, camera, and local placement.
- [ ] Task 11 (11A-11F): Deliver the Canvas renderer and approved assets.
- [ ] Task 12 (12A-12D): Connect accepted messages to speech bubbles.

### Checkpoint: Visual direction

- [ ] Human approves the original/appropriately licensed top-down office,
  palette, avatar scale, and representative desktop/mobile screenshots.
- [ ] Fifty participants receive unique valid anchors without overlap.
- [ ] The current client's avatar remains centered across placement, reconnect,
  viewport-resize, and world-edge cases while other avatar changes do not pan.
- [ ] Static scenes do not run a permanent animation loop.
- [ ] Full content remains usable through DOM with canvas unavailable.

### Phase 4: Polish and delivery

- [ ] Task 13 (13A-13E): Finish responsive, keyboard, and accessibility behavior.
- [ ] Task 14 (14A-14D): Add reproducible staging and container delivery.
- [ ] Task 15 (15A-15F): Run real-backend acceptance and align documentation.

### Checkpoint: Complete

- [ ] All acceptance criteria in `todo.md` are checked.
- [ ] All Gleam and browser suites pass with no unexpected console errors.
- [ ] Chromium, Firefox, and WebKit pass the release matrix.
- [ ] Backend serves the generated app and `/ws` from one origin.
- [ ] Manual keyboard, screen-reader smoke, responsive, two-browser chat, and
  reconnect checks pass.
- [ ] No generated output or unreviewed third-party artwork is committed.
- [ ] Ready for code, security, accessibility, and simplification review.

## Parallelization Opportunities

- After Task 0, Task 3 protocol work and Task 1 shell work are logically
  independent, but shared dependency files must not be edited concurrently.
- After Task 7 freezes the participant representation, Task 8 chat and Task 10
  pure scene work can proceed independently. Coordinate any shared `Model`/`Msg`
  edits before merging.
- Asset creation/provenance for Task 11 can proceed while Task 9 recovery is
  implemented. The renderer interface and `16px` tile contract must already be
  frozen.
- Task 14's local staging script can be designed before backend completion, but
  Docker and real-server verification wait for backend static delivery.
- Task 15 is sequential and cannot start until both frontend Task 14 and backend
  Tasks 7-10 are complete.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Backend error/close behavior changes during Tasks 7-9 | High | Gate frontend socket behavior on the finalized canonical matrix and share contract fixtures. |
| WebSocket callbacks race with reconnect | High | Tag every callback/timer with a generation and reject stale messages in pure transition tests. |
| A send is lost near disconnect | High | Never promise delivery, keep the draft until server echo, do not replay, and make retry manual. |
| Duplicate usernames corrupt identity or bubbles | High | Key presence, placement, authorship, and bubbles exclusively by opaque connection ID. |
| Canvas becomes an inaccessible second UI | High | Keep all essential content/actions in semantic DOM and make canvas non-interactive. |
| Pixel scaling blurs across DPR/layout changes | Medium | Separate coordinate spaces, use ResizeObserver, disable smoothing, round device geometry, and screenshot DPR 1/2. |
| Camera math causes jitter or exposes incorrect world regions | Medium | Derive it purely from self visual center and even viewport dimensions; test center, resize, reconnect, and edge crops. |
| Fifty avatars or bubbles clutter the scene | Medium | Author 50 anchors, Y-sort, clamp bubbles, show one three-line bubble per user, and validate crowded snapshots. |
| Render loop wastes battery | Medium | Dirty rendering only; animate solely during a bubble fade or approved sprite animation. |
| Third-party art has unclear rights | High | Create original assets or record an explicit compatible license and provenance before merge. |
| Browser tests become flaky or opaque to Codex | Medium | Fixed clocks/seeds/DPR, routed sockets, one worker, line reporter, retained failure traces, and few visual snapshots. |
| Build script deletes unintended files | High | Resolve exact paths, reject symlinks/unexpected targets, and clean only the explicit backend public directory. |
| Frontend lands before backend is usable | Medium | Use routed socket fixtures for frontend work and keep final same-origin acceptance as a hard gate. |

## Remaining Integration-Time Decisions

No product decision currently blocks Tasks 0-5. The following decisions are
deliberately resolved at named checkpoints:

- Task 6 must adopt the backend Task 7 finalized error room-context, close order,
  and post-error phase exactly.
- Task 11's original or licensed art and palette require human visual/provenance
  approval before speech-bubble polish proceeds.
- Task 14 must coordinate the ignored/staged `priv/public` policy and Docker
  shipment with backend Task 11; committing generated output still requires
  separate approval.

## Resolved Message Contract

Approved on 2026-08-09: chat is multiline. At the untrusted boundary, allow LF
and reject CR, Unicode line separator (`U+2028`), Unicode paragraph separator
(`U+2029`), every other C0/C1 control, and DEL. Then trim leading and trailing
whitespace and require `1-500` Unicode grapheme clusters, with every retained LF
counting toward the limit. The trusted message value therefore retains LF
(`U+000A`) as its only control character.

The composer is a multiline textarea: Enter sends, Shift+Enter inserts LF, and
Enter must not send while IME composition is active. The DOM chat log preserves
the full accepted line structure. Canvas bubbles wrap explicit lines before
ordinary word wrapping and may visually truncate to three lines without changing
the accepted message. Frontend Tasks 3 and 8 must match the updated canonical
backend specification and its fixtures before their acceptance criteria can pass.

## Reference Material

- [Lustre application API](https://hexdocs.pm/lustre/lustre.html)
- [Lustre managed effects](https://hexdocs.pm/lustre/lustre/effect.html)
- [Lustre development tools](https://hexdocs.pm/lustre_dev_tools/)
- [Lustre build and HTML configuration](https://hexdocs.pm/lustre_dev_tools/toml-reference.html)
- [Playwright CLI](https://playwright.dev/docs/test-cli)
- [Playwright WebSocket routing](https://playwright.dev/docs/api/class-page#page-route-web-socket)
- [Playwright accessibility testing](https://playwright.dev/docs/accessibility-testing)
- [Pixel Agents `OfficeCanvas.tsx`](https://github.com/pixel-agents-hq/pixel-agents/blob/main/webview-ui/src/office/components/OfficeCanvas.tsx)
- [Pixel Agents renderer](https://github.com/pixel-agents-hq/pixel-agents/blob/main/webview-ui/src/office/engine/renderer.ts)
- [Pixel Agents office state](https://github.com/pixel-agents-hq/pixel-agents/blob/main/webview-ui/src/office/engine/officeState.ts)
