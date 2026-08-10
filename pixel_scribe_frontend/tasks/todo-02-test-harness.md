## Task 2: Establish Gleam and Playwright test harnesses

**Description:** Add the standard Gleam test runner, Lustre view-test baseline,
and a deterministic Playwright setup that starts the Lustre dev server. Prove the
non-interactive CLI workflow before browser behavior becomes complex.

### Work units

- [x] **Task 2A — Add the Gleam test entry and one view test.**
  - **Done when:** `gleam test` discovers the suite and a focused test proves the
    initial model plus one semantic username-view assertion without production
    test hooks.
  - **Files:** `test/pixel_scribe_frontend_test.gleam`,
    `test/pixel_scribe_frontend/view_test.gleam`.
  - **Verify:** `gleam format --check src test`; `gleam build`; `gleam test`.
  - **Depends:** Task 1B.
- [x] **Task 2B — Configure deterministic Playwright execution.**
  - **Done when:** the config defines the Lustre dev server, base URL, bounded
    timeouts, ignored failure artifacts, and explicit Chromium/Firefox/WebKit
    projects with Chromium as the routine project.
  - **Files:** `playwright.config.ts`.
  - **Verify:** `bunx playwright test --list --project=chromium` starts and exits
    without downloading a browser or leaving a dev server.
  - **Depends:** Tasks 0B and 1C.
- [x] **Task 2C — Add the shell browser and axe checks.**
  - **Done when:** the headless test covers semantic locators, keyboard submit,
    320px bounds, horizontal overflow, console/page errors, and an unsuppressed
    WCAG A/AA axe scan.
  - **Files:** `e2e/app_shell.spec.ts`, `e2e/support/accessibility.ts`.
  - **Verify:** `bunx playwright install chromium` as explicit setup, then
    `bunx playwright test e2e/app_shell.spec.ts --project=chromium --reporter=line --workers=1`.
  - **Depends:** Tasks 2A-2B.

**Implementation notes:**

1. Add the standard Gleeunit entry point and one focused model/view test; do not
   add placeholder production APIs solely to create tests.
2. Configure Playwright with `testDir`, `baseURL`, the Lustre dev command in
   `webServer`, `reuseExistingServer: !CI`, retained-on-failure traces, failure-only
   screenshots, bounded timeouts, and explicit browser projects.
3. Make Chromium the routine project. Define Firefox/WebKit projects for the
   release matrix without hiding browser installation in test execution.
4. Add an app-shell spec that checks role/name locators, keyboard submission,
   320px layout bounds, no horizontal overflow, and no unexpected page/console
   errors. Add an axe helper configured for WCAG 2 A/AA and 2.1 A/AA tags.
5. Document targeted CLI syntax in comments or test README only if configuration
   is insufficient; keep the commands in `plan.md` authoritative.

**Acceptance criteria:**

- [x] `gleam test` discovers and runs frontend tests on the JavaScript target.
- [x] Playwright starts/stops the frontend predictably and the Chromium shell
  test passes headlessly with `--reporter=line --workers=1`.
- [x] Failure artifacts are written only to ignored directories, and axe scans
  the initial state without suppressing rules or excluding the application.

**Verification:**

- [x] `gleam format --check src test`
- [x] `gleam build`
- [x] `gleam test`
- [x] `gleam run -m lustre/dev build`
- [x] `bunx playwright install chromium` (explicit environment setup)
- [x] `bunx playwright test --project=chromium --reporter=line --workers=1`
- [x] Review that the Playwright process exits and does not leave a dev server.

**Dependencies:** Tasks 0-1.

**Files likely touched:**

- `test/pixel_scribe_frontend_test.gleam`
- `test/pixel_scribe_frontend/view_test.gleam`
- `playwright.config.ts`
- `e2e/app_shell.spec.ts`
- `e2e/support/accessibility.ts`

**Estimated scope:** Medium, 5 files.
