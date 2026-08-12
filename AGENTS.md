# AGENTS.md

## Start here

- This repository contains `pixel_scribe_frontend/` and
  `pixel_scribe_backend/`.
- Read the relevant subproject `README.md` and `AGENTS.md` before editing it.
- The canonical shared protocol is
  `pixel_scribe_backend/docs/mvp-backend-spec.md`. If code or documentation
  conflicts with it, stop and reconcile the mismatch rather than guessing.

## Product scope

- Pixel Scribe is a small virtual office with real-time WebSocket chat.
- The MVP has one room, `default`, with no accounts or authentication.
- Chat history is in memory and may disappear after a restart.
- Multiple active rooms, movement, persistence, offline delivery, voice, video,
  and screen sharing are out of scope unless explicitly requested.

## Shared rules

- Favor the smallest implementation that satisfies the current MVP.
- Treat cookies, WebSocket frames, and all client-provided values as untrusted.
- Decode and validate data at boundaries. Render usernames, messages, and errors
  as text; never log cookies, raw payloads, usernames, or message contents.
- Apply identity, presence, and message behavior by opaque IDs, never username.
- Keep the frontend, backend contract, protocol fixtures, tests, and README files
  aligned.
- Add focused tests for behavior changes and preserve unrelated working-copy
  changes.
- Ask before changing the public protocol or MVP scope, or introducing durable
  infrastructure, authentication, another UI framework/bundler, a game engine,
  Wasm, or media features.

## Frontend

- Build a browser-only Lustre SPA with explicit `Model`, `Msg`, `update`, and
  `view`; use Lustre effects for native WebSocket, timer, cookie, DOM, and Canvas
  work.
- Append chat only from accepted `message_sent` events. On reconnect, join again,
  replace the snapshot and `self_id`, deduplicate by ID, preserve the draft, and
  never replay offline sends.
- Keep protocol, socket effects, views, and Canvas rendering separate. Keep
  `.mjs` externals narrow and tested; never hand-edit generated JavaScript.
- Keep essential controls and content in accessible, keyboard-usable DOM and
  responsive down to 320px.
- Verify frontend changes from `pixel_scribe_frontend/` with:

```sh
gleam format --check src test
gleam build
gleam test
gleam run -m lustre/dev build
```

## Backend

- Use Gleam and Wisp for the WebSocket backend.
- Validate all client values and keep room/chat state in memory for the MVP.
- Do not introduce persistence or future media/authentication infrastructure
  without an explicit requirement. If persistence is later approved, prefer
  SQLite through `sqlight` for the MVP.
- Verify backend changes from `pixel_scribe_backend/` with its documented format,
  build, and test commands.

## Repository workflow

- This is one Jujutsu repository rooted in this parent folder. Run `jj root`
  before repository operations and ensure it resolves here.
- Never initialize or create nested `.git` or `.jj` metadata inside either
  subproject; nested repository markers cause Jujutsu to omit those files from
  snapshots.
- Keep each reviewable change in its own Jujutsu revision. After verification,
  run `jj describe -m "<type>: <short reason>"`, then `jj new` before the next
  change.
- Inspect `jj status` and the revision diff before describing or squashing a
  change. Do not commit generated build output unless explicitly approved.
