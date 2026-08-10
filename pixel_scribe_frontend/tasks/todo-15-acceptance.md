
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
  - **Done when:** invalid username/message, accepted LF and rejected newline/
    control cases, encoded-frame limits, rate limiting, room capacity where
    practical, unexpected disconnect, reconnect/new identity, snapshot
    replacement, draft preservation, and no replay match the canonical contract.
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
  - **Files:** `tasks/todo-15-acceptance.md` (evidence checkboxes only). Any implementation
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
