## Task 1: Bootstrap the explicit Lustre SPA shell

**Description:** Create the smallest browser application using
`lustre.application` and `lustre.start`, with explicit `Model`, `Msg`, `update`,
and `view`. Render a semantic username-entry shell and responsive page regions,
but do not connect a socket or render a canvas scene yet.

### Work units

- [x] **Task 1A — Create the explicit MVU skeleton.**
  - **Done when:** the entry point mounts one `lustre.application` on `#app`, and
    explicit initial `Model`, `Msg`, and no-op/local `update` compile without any
    socket, cookie, DOM, or canvas FFI.
  - **Files:** `src/pixel_scribe_frontend.gleam`,
    `src/pixel_scribe_frontend/model.gleam`,
    `src/pixel_scribe_frontend/update.gleam`.
  - **Verify:** `gleam format --check src`; `gleam build` — passed 2026-08-09.
  - **Depends:** Task 0C.
- [x] **Task 1B — Render the semantic username form.**
  - **Done when:** the view has one heading, a real labeled nickname field, native
    form submission, status/help copy, and a non-interactive office preview; input
    and submit messages update only local state.
  - **Files:** `src/pixel_scribe_frontend/view.gleam`,
    `src/pixel_scribe_frontend/update.gleam`.
  - **Verify:** `gleam format --check src`; `gleam build`;
    `gleam run -m lustre/dev build` — passed 2026-08-10.
  - **Depends:** Task 1A.
- [x] **Task 1C — Style the responsive shell.**
  - **Done when:** the shell is readable without horizontal overflow at 320px,
    keyboard focus is visible, the native media query uses the `768px` layout
    breakpoint, and the `22rem` rail is a named CSS custom property.
  - **Files:** `assets/styles.css`.
  - **Verify:** `gleam run -m lustre/dev build`; manually inspect generated assets
    and keyboard form submission at 320px — passed 2026-08-10.
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

- [x] The generated page mounts one Lustre SPA on `#app` and renders without
  server components or handwritten DOM mutation.
- [x] Username entry is usable with keyboard and native form submission, and all
  controls have visible labels/focus styling.
- [x] The shell remains readable at 320px; the native media query uses the
  `768px` breakpoint and the `22rem` rail is a named CSS custom property.

**Verification:**

- [x] `gleam format --check src`
- [x] `gleam build`
- [x] `gleam run -m lustre/dev build`
- [x] Confirm `dist/index.html`, bundled JS, and copied `styles.css` exist.
- [x] Run `gleam run -m lustre/dev start` and manually submit the form by keyboard.

**Dependencies:** Task 0.

**Files likely touched:**

- `src/pixel_scribe_frontend.gleam`
- `src/pixel_scribe_frontend/model.gleam`
- `src/pixel_scribe_frontend/update.gleam`
- `src/pixel_scribe_frontend/view.gleam`
- `assets/styles.css`

**Estimated scope:** Medium, 5 files.

