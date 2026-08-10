
## Task 14: Add reproducible staging and container delivery

**Description:** Build to ignored `dist/`, safely stage a clean copy into backend
`priv/public`, remove superseded placeholders, and add a production container
frontend stage. Generated output remains uncommitted.

### Work units

- [ ] **Task 14A — Implement the safe staging script.**
  - **Done when:** one repository-root command resolves fixed paths, validates
    source/target markers, rejects symlinks/unexpected targets, builds, verifies
    `dist/index.html`, cleans only exact backend `priv/public`, and copies all
    output with fail-fast behavior.
  - **Files:** `../scripts/stage_frontend.sh`.
  - **Verify:** shell syntax check; run from clean artifacts twice; compare exact
    `dist/` and target trees; deliberately test safe refusal cases without using
    a broad destructive target.
  - **Depends:** Task 13E and coordinated backend static-delivery target.
- [ ] **Task 14B — Align generated-output policy and delivery docs.**
  - **Done when:** frontend build/staged output is ignored, lock/source files stay
    tracked, superseded placeholder policy is explicit, and docs give exact dev,
    test, staging, and same-origin commands.
  - **Files:** `../.gitignore`, `README.md`.
  - **Verify:** `jj status`; inspect ignore behavior and documentation commands;
    no generated bundle is tracked.
  - **Depends:** Task 14A.
- [ ] **Task 14C — Add the reproducible frontend container stage.**
  - **Done when:** Docker builds from locked Gleam/Bun inputs, stages only `dist/`
    into the backend build before shipment export, and the runtime image contains
    no Bun/Node/Playwright/source tree.
  - **Files:** `../Dockerfile`.
  - **Verify:** clean container build; inspect runtime contents and served `/` plus
    a known asset; no browser installation occurs.
  - **Depends:** Task 14B and backend static handler Task 10.
- [ ] **Task 14D — Prove staging and shipment integration.**
  - **Done when:** repeated staging leaves no stale file, backend static tests pass,
    the container serves the complete app, unknown paths remain 404, and status
    shows no unintentionally tracked generated asset.
  - **Files:** `tasks/todo-14-delivery.md` (evidence checkboxes only). Any implementation
    defect requires a separately reviewed corrective unit in its owning package.
  - **Verify:** all frontend checks, backend static tests, staging twice, container
    smoke, and `jj status`/`jj diff`.
  - **Depends:** Task 14C.

**Implementation notes:**

1. Add one repository-level script with no ambiguous current-directory behavior.
   Resolve repo/source/target paths, require expected marker directories, reject
   symlink/unexpected targets, build frontend, verify `dist/index.html`, clean only
   the exact backend public target, and copy the complete output.
2. The script must fail on any build/copy error and must not use `$HOME`, broad
   globs, workspace-root deletion, or an unresolved environment variable as a
   destructive target.
3. Remove tracked placeholder public pages when coordinated with the backend.
   Ignore generated staged contents and preserve a documented way to recreate
   them. Do not commit a generated bundle.
4. Extend the Dockerfile with a pinned/reproducible frontend build stage using the
   locked Gleam/Bun inputs, then copy only `dist/` into the backend build before
   the Erlang shipment export. Production image contains no Node/Bun/Playwright or
   source tree.
5. Update development/build docs with frontend-only dev, mocked browser test,
   staging, backend-served same-origin, and container commands.

**Acceptance criteria:**

- [ ] One command from repository root creates a clean, complete backend public
  tree from source/locks and cannot clean outside the validated explicit target.
- [ ] A clean Docker build compiles the frontend before backend shipment and the
  runtime image contains/serves assets without frontend build/test tooling.
- [ ] `dist/` and staged generated public files remain uncommitted/reproducible;
  placeholder pages and docs no longer describe the old state.

**Verification:**

- [ ] Run staging from a clean frontend artifact state; inspect the exact target
  tree and compare it to `dist/`.
- [ ] Run the staging command twice and verify no stale/duplicate file survives.
- [ ] All frontend format/build/test/browser checks pass before staging.
- [ ] Backend static handler tests pass against the staged tree once backend Task
  10 exists.
- [ ] Build and smoke-test the container without installing Playwright browsers.
- [ ] `jj status` shows no generated bundle/staged asset unintentionally tracked.

**Dependencies:** Task 13 and coordinated backend static-delivery work.

**Files likely touched:**

- `../scripts/stage_frontend.sh`
- `../Dockerfile`
- `../.gitignore`
- `README.md`
- `../pixel_scribe_backend/priv/public/` placeholder/generated policy

**Estimated scope:** Medium, 4 files plus one explicit generated-target policy.
