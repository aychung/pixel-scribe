# AGENTS.md

## Start here

- Read `README.md` for the product, UX, frontend contract, and technical choices.
- The canonical protocol is
  `../pixel_scribe_backend/docs/mvp-backend-spec.md`. If it conflicts with the
  frontend, stop and reconcile them rather than guessing.
- The MVP has one room, `default`. Auth, multiple active rooms, movement,
  persistence, offline delivery, and media are out of scope.

## Repository

- This project uses Jujutsu (`jj`) for version control.
- The `jj` repository is rooted in the parent folder, `pixel_scribe`.

## Required behavior

1. Prefill a frontend-owned username preference, connect to `/ws`, and send one
   `join_room` for `default`.
2. Wait for `room_state` before enabling chat. Apply presence and message events
   by opaque connection/message ID, never by username.
3. Append messages only from `message_sent`. On reconnect, join again, replace
   the snapshot and `self_id`, deduplicate messages, preserve the draft, and do
   not replay offline sends.
4. Show recoverable errors inline and give terminal errors an appropriate retry.

Desktop uses a flexible canvas with a fixed right chat rail; mobile places chat
below the canvas. Essential content and controls must remain accessible DOM,
keyboard usable, and responsive down to 320px.

## Implementation rules

- Build a browser-only Lustre SPA with `lustre.application` and `lustre.start`.
  Do not use Lustre server components or change the backend integration.
- Keep `Model`, `Msg`, `update`, and `view` explicit. Use Lustre effects for the
  native JSON WebSocket, reconnect timers, cookies, DOM access, and Canvas 2D.
- Decode untrusted data at the boundary, tolerate additive fields, and render
  usernames, messages, and errors only through text-safe APIs. Do not log them or
  cookies/raw payloads.
- Keep protocol, socket effects, Lustre views, and Canvas rendering separate.
  Keep `.mjs` externals narrow and tested; never hand-edit generated JavaScript.
- Start with Canvas 2D. Add Wasm only for a measured CPU-bound hot path behind the
  renderer boundary.
- Use Lustre's official development tools and favor minimal dependencies. Add
  focused codec, update, view, browser, accessibility, responsive, and renderer
  tests with behavior changes.

## Workflow

- Preserve unrelated working-copy changes. This is a Jujutsu repository rooted
  at the parent `pixel_scribe` directory.
- Keep `README.md`, protocol tests, and the backend contract aligned.
- Ask before changing the public contract or MVP scope; adding another UI
  framework, alternative bundler, game framework, or Wasm; or committing
  generated output.
- Once source exists, verify at minimum with:

```sh
gleam format --check src test
gleam build
gleam test
gleam run -m lustre/dev build
```

- Keep each reviewable set of changes in its own Jujutsu revision. After verifying
  a change set, run `jj describe -m "<type>: <short reason>"`, then run `jj new`
  before starting the next change set.
