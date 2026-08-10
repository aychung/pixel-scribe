## Task 0: Lock the frontend toolchain and artifact policy

**Description:** Add only the approved runtime/build/test dependencies, configure
Lustre's official build, establish Bun/Playwright scripts, and ignore generated
artifacts. This task creates a deterministic foundation but no product behavior.

### Work units

- [x] **Task 0A — Resolve Gleam dependencies.**
  - **Done when:** `lustre` and `gleam_json` are direct dependencies,
    `lustre_dev_tools` remains development-only, and the generated manifest diff
    contains no unexplained direct package.
  - **Files:** `gleam.toml`, `manifest.toml`.
  - **Verify:** `gleam deps download`; `gleam build`; inspect the complete lockfile
    diff.
  - **Depends:** approved plan.
- [x] **Task 0B — Resolve browser-test dependencies and scripts.**
  - **Done when:** Bun is pinned in `packageManager`, only Playwright and axe are
    direct development dependencies, and scripts expose the documented headless
    test commands without installing browsers.
  - **Files:** `package.json`, `bun.lock`.
  - **Verify:** `bun install --frozen-lockfile`; `bunx playwright --version`;
    inspect dependency scripts and the complete lockfile diff.
  - **Depends:** Task 0A.
- [x] **Task 0C — Configure Lustre output and artifact ignores.**
  - **Done when:** Lustre uses system Bun, builds a minified `dist/` app with the
    approved HTML metadata and stylesheet, Tailwind processing is disabled, and
    every generated path in the parent acceptance criteria is ignored.
  - **Files:** `gleam.toml`, `../.gitignore`.
  - **Verify:** `gleam build`; `gleam run -m lustre/dev build`; inspect `dist/` and
    `jj diff --summary` without adding generated output — passed 2026-08-09.
  - **Depends:** Tasks 0A-0B.

**Implementation notes:**

1. From `pixel_scribe_frontend/`, run `gleam add lustre gleam_json` and
   `gleam add lustre_dev_tools --dev`. Keep `gleeunit` as a dev dependency.
2. Add `@playwright/test` and `@axe-core/playwright` as Bun dev dependencies and
   commit the generated `bun.lock`. Record the project package manager/version.
3. Configure `tools.lustre` to use the system Bun, emit a minified production
   build into `dist/`, generate the default `#app` mount, set `lang = "en"`, set
   the page title, link `/styles.css`, and disable unrequested Tailwind behavior.
4. Add scripts for the checked-in browser commands; scripts must not install
   browsers or OS packages implicitly.
5. Ignore frontend `build/`, `dist/`, `.lustre/`, `node_modules/`, Playwright
   reports/results, and staged generated backend public output while preserving
   source assets and lockfiles.

**Acceptance criteria:**

- [x] Gleam resolves `lustre`, `gleam_json`, and `lustre_dev_tools` through its
  tooling; Bun resolves only the approved browser-test dependencies.
- [x] `gleam.toml`, `manifest.toml`, `package.json`, and `bun.lock` form a
  deterministic, reviewed dependency/build contract.
- [x] Generated bundles, caches, browser binaries, traces, screenshots, and
  staged backend assets are ignored; source and lockfiles remain tracked.

**Verification:**

- [x] Review the complete dependency and lockfile diffs; no unrelated package is
  direct and no generated lockfile was hand-edited.
- [x] `gleam deps download`
- [x] `gleam build`
- [x] `bun install --frozen-lockfile`
- [x] `bunx playwright --version`
- [x] `jj diff --summary`

**Dependencies:** Approved plan.

**Files likely touched:**

- `gleam.toml`
- `manifest.toml`
- `package.json`
- `bun.lock`
- `../.gitignore`

**Estimated scope:** Medium, 5 files.

