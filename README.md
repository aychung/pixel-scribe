# pixel_scribe

Pixel Scribe is a browser-based virtual office built with Gleam. The backend
runs on the BEAM and owns the `default` room's presence and chat state. The
frontend is a client-side Lustre application that compiles to JavaScript.

## Current status

The backend Tasks 0–10 are implemented and covered by the automated backend
tests. They provide the HTTP server, static-file handler, JSON WebSocket
contract, supervised `default` room, presence, bounded in-memory history, rate
limiting, liveness cleanup, origin checks, and security headers.

The frontend currently contains the Lustre shell, username preference, protocol
validation, and pure connection-state model. Its browser WebSocket effect, joined
chat workspace, local office world, Canvas renderer, and approved art assets are
not implemented yet. The current scene state is a placeholder, so the browser
shell is not the completed real-backend MVP.

Task 11's reproducible artifact staging is implemented. The frontend remains a
shell rather than the completed real-time browser client, so no manual browser
acceptance is claimed yet.

## Repository layout

```text
pixel_scribe-be/
├── README.md
├── Dockerfile
├── pixel_scribe_backend/
│   ├── src/
│   ├── test/
│   ├── docs/mvp-backend-spec.md
│   └── tasks/
└── pixel_scribe_frontend/
    ├── src/
    ├── test/
    ├── e2e/
    ├── assets/
    └── tasks/
```

The backend specification is the canonical WebSocket contract. The frontend
package README describes the planned client UX and its dependency on that
contract.

## Implemented backend contract

- One public room: `default`.
- Usernames are display labels, not identities; duplicate labels are allowed.
- Each connection receives a server-issued connection ID.
- Accepted messages are broadcast to the room, including the sender.
- New joins receive the latest 50 accepted messages from in-memory history.
- `GET /healthz` reports process health; `GET /ws` upgrades to the WebSocket;
  `/` and known static paths serve files from `priv/public` by default.
- The 51st simultaneous presence is rejected. Chat allows a burst of five
  messages and refills at one message per second per connection.

Authentication, durable storage, additional active rooms, server-side avatar
coordinates or movement, delivery acknowledgements, offline delivery, multiple
backend replicas, voice, video, and screen sharing are intentionally deferred.
The backend's full limits, errors, lifecycle, and security behavior are in
[`pixel_scribe_backend/docs/mvp-backend-spec.md`](pixel_scribe_backend/docs/mvp-backend-spec.md).

## Development commands

Commands below are the checks currently supported by the repository. Run each
package's commands from that package directory.

### Backend

```sh
cd pixel_scribe_backend
gleam format --check src test
gleam build
gleam test
```

To run the backend locally, provide a non-empty `SECRET_KEY_BASE` of at least
64 bytes. This development-only value is deliberately not a production secret:

```sh
cd pixel_scribe_backend
SECRET_KEY_BASE='0123456789012345678901234567890123456789012345678901234567890123' \
  ENVIRONMENT=development \
  DEVELOPMENT_ORIGINS='http://localhost:1234' \
  gleam run
```

The default port is `4000`. `PORT`, `STATIC_DIRECTORY`, and
`DEVELOPMENT_ORIGINS` are validated configuration values. Production requires
`ENVIRONMENT=production` and does not accept development origins.

### Frontend

The frontend uses the Bun version declared in `package.json` for Playwright
development dependencies and system Bun for the Lustre build.

```sh
cd pixel_scribe_frontend
bun install --frozen-lockfile
gleam format --check src test
gleam build
gleam test
gleam run -m lustre/dev build
```

The last command writes the generated entry page, JavaScript bundle, and
`styles.css` to `pixel_scribe_frontend/dist/`. `bun run test:e2e` and
`bun run test:e2e:focused` run the configured frontend shell suite; they start
the Lustre development server and do not provide real-backend WebSocket
acceptance.

### Frontend artifact delivery

From the repository root, the checked-in command builds the frontend into a
clean ignored artifact directory and replaces the backend's static target with
the generated entry page, bundle, and stylesheet:

```sh
./scripts/build_frontend.sh
```

The script removes stale files, fails on unexpected top-level artifacts or
symlinks, and leaves generated output uncommitted. Run it again after any
frontend change; the output is deterministic for the locked toolchain.

For a static-only smoke procedure without copying, first build the frontend.
From `pixel_scribe_backend/`, start the backend in one terminal against the
normalized absolute `dist/` path:

```sh
STATIC_DIRECTORY="$(cd ../pixel_scribe_frontend/dist && pwd)" \
SECRET_KEY_BASE='0123456789012345678901234567890123456789012345678901234567890123' \
ENVIRONMENT=development \
gleam run
```

In a second terminal, still from `pixel_scribe_backend/`, check:

```sh
curl -i http://127.0.0.1:4000/healthz
curl -i http://127.0.0.1:4000/
curl -i http://127.0.0.1:4000/styles.css
curl -i http://127.0.0.1:4000/does-not-exist
```

This checks HTTP/static behavior only; it does not verify a browser, WebSocket,
two-client presence, chat, reconnect, or Canvas flow.

### Pending Task 11 browser smoke procedure

After the frontend WebSocket effect exists, run the
backend against the staged target and open its backend origin in two separate
browser contexts. Join `default` from both contexts, check distinct
connection IDs and presence updates, exchange accepted plain-text messages,
disconnect one context, then reconnect it and check snapshot/history behavior.
Record viewport, browser, backend configuration, and observed results. This
procedure is not currently passing because the frontend is not yet connected to
the backend and no same-origin live evidence has been recorded.

## Verification boundary

The automated evidence includes package checks, the frontend bundle command, the
staging command, and a live backend integration test covering HTTP delivery and
the two-client WebSocket lifecycle. Full browser acceptance still requires the
frontend WebSocket effect and a manual two-browser smoke test.
