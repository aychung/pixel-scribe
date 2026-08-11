# Pixel Scribe Backend

This package is the BEAM backend for Pixel Scribe's virtual office. It uses
Wisp/Mist for HTTP and WebSocket delivery and keeps the MVP room state in
supervised in-memory actors.

## Implemented behavior

- Serves `GET /healthz`, `GET /ws`, and static files from `priv/public`.
- Supports one public room, `default`.
- Accepts non-unique display usernames and assigns each connection an opaque
  server-issued connection ID.
- Broadcasts accepted plain-text messages, including back to the sender.
- Keeps and snapshots at most the latest 50 accepted messages.
- Removes disconnected presences idempotently and recovers from room failure by
  restarting a clean room.
- Rejects chat above a burst of five messages until the per-connection bucket
  refills at one message per second.

The canonical event shapes, validation rules, error behavior, origin policy,
security headers, and supervision design are in
[`docs/mvp-backend-spec.md`](docs/mvp-backend-spec.md).

## Limits and accepted MVP risks

- Usernames: trim, then 1–32 Unicode grapheme clusters; no control characters or
  line breaks.
- Room IDs: `[a-z0-9][a-z0-9_-]{0,63}`; only `default` is supported.
- Messages: trim, then 1–500 Unicode grapheme clusters; LF is allowed for
  multiline text, while other controls are rejected.
- Client WebSocket text frames: at most 8,192 UTF-8 bytes.
- Room capacity: 50 simultaneous presences.
- In-memory history: latest 50 accepted messages; a process or room restart
  loses that history and all presences.
- Join deadline: 10 seconds.

The MVP deliberately has no authentication or authorization. Anyone who can
reach the service can use the public `default` room and consume its capacity;
use an authenticating reverse proxy or VPN for private deployments. The service
is single-instance and has no durable storage or distributed room coordination.
These are accepted MVP boundaries, not hidden guarantees.

## Checks and local run

Run from this package directory:

```sh
gleam format --check src test
gleam build
gleam test
```

The backend requires `SECRET_KEY_BASE` even in development. It must contain at
least 64 bytes, have no surrounding whitespace, and contain no control
characters. This command uses a local-only placeholder and listens on the
default port, 4000:

```sh
SECRET_KEY_BASE='0123456789012345678901234567890123456789012345678901234567890123' \
  ENVIRONMENT=development \
  DEVELOPMENT_ORIGINS='http://localhost:1234' \
  gleam run
```

Configuration also accepts validated `PORT`, `STATIC_DIRECTORY`, and
`DEVELOPMENT_ORIGINS` values. Production uses `ENVIRONMENT=production` and
does not allow development origins.

## Frontend artifact boundary

The frontend package currently builds a Lustre shell, not the completed
real-time office UI:

```sh
cd ../pixel_scribe_frontend
gleam format --check src test
gleam build
gleam test
gleam run -m lustre/dev build
```

That package build writes `dist/index.html`, `dist/pixel_scribe_frontend.js`,
and `dist/styles.css`. From the repository root, use the checked-in staging
command to build and copy those artifacts into this package's static target:

```sh
./scripts/build_frontend.sh
```

The script removes stale placeholder files, rejects unexpected top-level
artifacts and symlinks, and does not commit generated output. The backend's live
integration test verifies the staged entry page and assets plus the two-client
WebSocket lifecycle. The frontend browser client is still incomplete, so this
does not claim full browser/WebSocket acceptance.

For the current frontend-only browser checks, run from
`../pixel_scribe_frontend`:

```sh
bun install --frozen-lockfile
bun run test:e2e
```

Those tests start the Lustre development server and cover the shell only; they
do not exercise this backend's WebSocket with two browser clients.

## Deferred features

Authentication, durable chat storage, additional active rooms, server-side
avatar coordinates or movement, delivery acknowledgements, offline delivery,
multiple backend replicas, voice, video, screen sharing, and production
artifact/container staging are intentionally deferred. Local client-side
avatars and Canvas rendering belong to the frontend and must not be added to the
backend protocol merely to make the current placeholder shell appear complete.
