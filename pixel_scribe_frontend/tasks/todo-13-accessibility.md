## Task 13: Finish responsive, keyboard, focus, and accessibility behavior

**Description:** Complete production UI polish across all states and required
viewports. This task fixes accessibility/layout defects exposed by tests; it does
not redesign protocol or add new features.

### Work units

- [x] **Task 13A — Finish responsive and safe-area layout.**
  - **Done when:** mobile and desktop use the approved rows/columns, `100dvh`,
    safe-area padding, useful canvas/chat minimums, independent log scrolling,
    visible composer, and no body overflow at required widths/orientations.
  - **Files:** `assets/styles.css`, `e2e/responsive.spec.ts`.
  - **Verify:** Chromium checks at 320/768/1024/1440, portrait/landscape where
    relevant, crowded content, reconnect/blocked states, and software-keyboard
    emulation available to the test.
  - **Depends:** visual checkpoint.
- [x] **Task 13B — Finish deterministic focus and keyboard behavior.**
  - **Done when:** username error, successful join, terminal state, retry, and
    composer focus follow the plan; ordinary presence/chat never steal focus; all
    actions including multiline send remain keyboard-complete.
  - **Files:** `src/pixel_scribe_frontend/view.gleam`,
    `test/pixel_scribe_frontend/view_test.gleam`,
    `e2e/accessibility.spec.ts`.
  - **Verify:** focused view and Chromium keyboard/focus tests plus all Gleam
    checks.
  - **Depends:** Task 13A.
- [x] **Task 13C — Finish semantic and visual accessibility.**
  - **Done when:** forms/lists/log/status/canvas fallback, busy/disabled states,
    visible focus, non-color status, 4.5:1 text contrast, 200% text zoom, long
    content, and live-region restraint satisfy the parent criteria.
  - **Files:** `src/pixel_scribe_frontend/view.gleam`, `assets/styles.css`,
    `test/pixel_scribe_frontend/view_test.gleam`.
  - **Verify:** view tests plus all Gleam checks and production bundle.
  - **Depends:** Task 13B.
- [x] **Task 13D — Run unsuppressed axe state coverage.**
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
  - **Files:** `tasks/todo-13-accessibility.md` (evidence checkboxes only). Implementation defects
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

- [x] Every product state is keyboard-complete, focus-correct, text-safe, and has
  no automatically detectable WCAG A/AA violation.
- [x] Required viewport/orientation/crowded-content tests show no clipped controls,
  hidden composer, body horizontal scroll, unusable canvas, or safe-area collision.
- [ ] Canvas remains supplementary: disabling/removing it leaves join, status,
  participants, errors, chat history, and composer understandable and usable.

**Verification:**

- [x] View tests cover roles, labels, descriptions, disabled/busy, live regions,
  focus targets, duplicate/long content, and canvas fallback.
- [x] `gleam format --check src test`
- [x] `gleam build`
- [x] `gleam test`
- [x] Playwright responsive/accessibility suites pass in Chromium.
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
