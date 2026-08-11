# Code Review: Backend Tasks 10 and 11

**Reviewed revisions:** `y`, `vz`, `l`  
**Review date:** 2026-08-10  
**Verdict:** Request changes

## Scope

This review covers the implementation of Tasks 10 and 11 from
`tasks/todo.md` and `tasks/plan.md`, including:

- HTTP configuration, routing, static-file delivery, security headers, and
  WebSocket origin policy.
- Frontend artifact staging and live MVP integration tests.
- Production container integration.
- Logic, code quality, test coverage, documentation, and opportunities to
  simplify the implementation.

## Findings

### 1. Critical: The production container is unreachable

`Dockerfile` sets `HOST=0.0.0.0`, but the application never reads that value or
calls `mist.bind`. The web server configuration only sets the port, so Mist keeps
its default `localhost` binding.

This was reproduced using the production image:

- The image built successfully.
- A host request to the mapped `/healthz` endpoint returned `HTTP 000` with a
  connection reset.
- The container logged `Listening on http://127.0.0.1:80`.

Consequently, the server cannot receive traffic through Docker's published port.

**Relevant code:**

- `Dockerfile:20`
- `src/pixel_scribe_backend/web.gleam:35`

**Recommended change:** Add a validated bind address to application
configuration, pass it through the supervisor, call `mist.bind`, and add a
container-level health smoke test.

### 2. Critical: Same-origin WebSockets fail behind a TLS-terminating proxy

The origin check constructs the expected origin from the scheme and host seen by
Mist. When an HTTPS/WSS deployment uses a TLS-terminating reverse proxy, Mist sees
the upstream HTTP connection. The browser sends an origin such as
`https://example.com`, but the backend compares it with `http://example.com` and
rejects the upgrade.

This conflicts with the documented deployment model, which explicitly permits
Wisp to run behind a TLS-terminating reverse proxy.

The new MVP integration test does not cover this path. It uses the legacy
`web.mist_handler`, which performs no origin check, and its raw WebSocket request
does not include an `Origin` header.

**Relevant code:**

- `src/pixel_scribe_backend/web.gleam:126`
- `src/pixel_scribe_backend/web.gleam:225`
- `test/pixel_scribe_backend/mvp_integration_test.gleam:197`
- `test/pixel_scribe_backend/mvp_integration_test.gleam:297`
- `docs/mvp-backend-spec.md:200`

**Recommended change:** Derive the expected origin from a validated public origin
or explicitly trusted proxy configuration. Exercise the configured production
handler in integration tests, including HTTPS-origin/proxied-request behavior.

### 3. Required: The documented backend test command fails on a clean checkout

Files under `pixel_scribe_backend/priv/public` are ignored, while both the web
unit test and MVP integration test require generated frontend files to exist.

Observed results:

- Before frontend staging: `77 passed, 2 failures`.
- After `./scripts/build_frontend.sh`: `79 passed, no failures`.

The two failures were the entry-page assertions in `web_test.gleam` and
`mvp_integration_test.gleam`. A clean checkout therefore cannot run the documented
backend `gleam test` command successfully without an undocumented prerequisite.

**Relevant code:**

- `../.gitignore:12`
- `test/pixel_scribe_backend/web_test.gleam:22`
- `test/pixel_scribe_backend/mvp_integration_test.gleam:25`
- `../README.md:70`

**Recommended change:** Choose one explicit verification boundary:

1. Make artifact staging a documented and automated prerequisite for the
   repository-level acceptance suite; or
2. Use committed, non-generated fixtures for package-level static-handler tests
   and keep real generated-artifact verification in a separate repository-level
   integration job.

The second option keeps normal backend tests deterministic and independent of the
frontend toolchain.

### 4. Required: Wisp key handling contradicts the task and specification

The configuration loader requires `SECRET_KEY_BASE`, validates it, and prevents
the application from starting when it is absent. The canonical specification
instead says that the server may generate any adapter-valid key at startup, keep
it only in memory, and replace it after restart because the MVP does not use Wisp
signing, encryption, or backend-owned cookies.

The supervisor documentation also says the key is generated in memory, although
the implementation obtains it from the environment.

**Relevant code:**

- `src/pixel_scribe_backend/config.gleam:23`
- `src/pixel_scribe_backend/config.gleam:104`
- `src/pixel_scribe_backend/supervisor.gleam:9`
- `docs/mvp-backend-spec.md:749`

**Recommended change:** Generate `wisp.random_string(64)` once during application
startup. Retain an injectable test key only at the test/server-construction
boundary. This would remove secret-related configuration, validation, tests, and
documentation while matching the approved design.

### 5. Required: Structured lifecycle logging is incomplete

The specification requires structured logs for application start and stop,
joins, leaves, rejected joins, and unexpected failures. Relevant room logs must
include the room ID, connection ID, and current user count without recording
usernames or message contents.

The implementation only logs application start and stop. The authoritative join,
join-rejection, and leave transitions have no application instrumentation.

**Relevant code:**

- `src/pixel_scribe_backend.gleam:15`
- `src/pixel_scribe_backend/room.gleam:125`
- `src/pixel_scribe_backend/room.gleam:222`
- `docs/mvp-backend-spec.md:867`

**Recommended change:** Add logs at the authoritative room state transitions and
sanitized failure boundaries. Do not log usernames, chat contents, cookies, raw
payloads, or the Wisp key.

### 6. Required: Documentation is stale after revision `l`

The backend README says production artifact/container staging is intentionally
deferred, but the Dockerfile now builds the frontend and includes its generated
artifacts in the runtime image. This conflicts with Task 11's requirement that
documentation match delivered behavior.

**Relevant code:**

- `README.md:107`
- `../Dockerfile:1`

**Recommended change:** Document the production container workflow and its
required runtime configuration after the bind/origin issues are corrected.

## Simplification Opportunities

### Collapse the web-handler variants

`web.gleam` contains three substantially similar handler constructors:

- `mist_handler`
- `mist_handler_with_origins`
- `mist_handler_with_options`

Use one configuration-driven handler path. Removing the origin-free public path
would also prevent integration tests or future callers from accidentally
bypassing production origin policy.

### Use one generic security-header helper

The same six headers are implemented once for `wisp.Response` and again for
`Response(mist.ResponseData)`. A helper parameterized as `Response(body)` can use
`gleam/http/response.set_header` for either body type.

### Reuse integration-test infrastructure

The new `mvp_integration_test.gleam` is 525 lines, while the existing
`websocket_integration_test.gleam` is 574 lines. They duplicate raw TCP/WebSocket
clients, frame handling, server lifecycle management, and protocol decoders.

Extract shared test support into focused modules, or extend the existing live
integration suite. The Task 11 test should then contain only the new artifact and
end-to-end acceptance assertions.

### Remove unnecessary secret configuration

Generating the adapter key in memory eliminates a sizeable portion of the new
configuration module, its error variants, environment manipulation tests, and
run-command documentation. This is the highest-value simplification in the Task
10 implementation.

## Verification Performed

| Check | Result |
|---|---|
| Backend format check | Passed |
| Backend build | Passed |
| Backend tests before artifact staging | Failed: 77 passed, 2 failed |
| `./scripts/build_frontend.sh` | Passed |
| Backend tests after artifact staging | Passed: 79 tests |
| Frontend format check | Passed |
| Frontend build | Passed |
| Frontend tests | Passed: 88 tests |
| `bash -n scripts/build_frontend.sh` | Passed |
| Production Docker image build | Passed |
| Production container `/healthz` from host | Failed: HTTP 000 |
| Jujutsu working copy after review | Clean |

## Final Recommendation

Do not mark Tasks 10 and 11 complete or pass the final review gate until the
production bind and proxied-origin defects are fixed, the clean-checkout test
contract is made deterministic, the Wisp key behavior matches the specification,
and required lifecycle logging and documentation are completed.
