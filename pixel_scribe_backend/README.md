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

The backend generates its Wisp adapter key in memory at startup, so
`SECRET_KEY_BASE` is not required. This command listens on the default port,
4000:

```sh
ENVIRONMENT=development \
  DEVELOPMENT_ORIGINS='http://localhost:1234' \
  gleam run
```

From the repository root, rebuild and stage the frontend before starting the
backend with:

```sh
ENVIRONMENT=development \
  DEVELOPMENT_ORIGINS='http://localhost:1234' \
  ./scripts/run_backend.sh
```

Runtime configuration is validated as follows:

- `HOST` is an optional bind address, defaulting to `localhost`.
- `PORT` is an optional TCP port from 1 through 65,535, defaulting to `4000`.
- `STATIC_DIRECTORY` is an optional path without parent-directory segments or
  control characters, defaulting to `priv/public`.
- `ENVIRONMENT` defaults to `development`; set it to `production` for deployed
  instances. Production rejects non-empty `DEVELOPMENT_ORIGINS`.
- `DEVELOPMENT_ORIGINS` is an optional comma-separated list of validated HTTP or
  HTTPS origins. Development defaults to `http://localhost:1234`; an empty value
  allows no additional origins.
- `PUBLIC_ORIGIN` is an optional validated HTTP or HTTPS origin without a path,
  wildcard, or credentials. Set it to the public HTTPS origin when a
  TLS-terminating reverse proxy fronts the backend; otherwise same-origin checks
  use the request origin.

### Production container

From the repository root, build and run the production image:

```sh
docker build --tag pixel-scribe:local .
docker run --rm --name pixel-scribe \
  --publish 127.0.0.1:4000:80 \
  --env ENVIRONMENT=production \
  pixel-scribe:local
```

The Dockerfile builds the frontend and includes its generated artifacts in the
runtime image. It sets `HOST=0.0.0.0` and `PORT=80`; the application reads both
values and serves the staged frontend from its default `priv/public` directory.
For a TLS-terminating reverse proxy, also set, for example,
`--env PUBLIC_ORIGIN=https://office.example.com`.

The checked-in container health smoke command builds an image, starts it with
`ENVIRONMENT=production`, verifies `/healthz` through a temporary published
port, then checks the Docker-generated `/`, `/styles.css`, and
`/pixel_scribe_frontend.js` for successful responses, exact content types, and
stable generated-content markers before removing its container and temporary
image. It does not perform browser, WebSocket, or full UI acceptance:

```sh
./scripts/container_health_smoke.sh
```

## Frontend artifact boundary

The frontend package currently builds the Lustre shell, native WebSocket join,
presence workspace, and accepted-message chat slices, not the completed
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
WebSocket lifecycle. Real-backend browser acceptance, the office renderer, and
approved art remain incomplete, so this does not claim full browser/WebSocket
acceptance.

For the current frontend-only browser checks, run from
`../pixel_scribe_frontend`:

```sh
bun install --frozen-lockfile
bun run test:e2e
```

Those tests start the Lustre development server and cover routed browser client
slices; they do not exercise this backend's WebSocket with two browser clients.

## Deferred features

Authentication, durable chat storage, additional active rooms, server-side
avatar coordinates or movement, delivery acknowledgements, offline delivery,
multiple backend replicas, voice, video, and screen sharing are intentionally
deferred. Local client-side avatars and Canvas rendering belong to the frontend
and must not be added to the backend protocol merely to make the current
placeholder office scene appear complete.
