# Pixel Scribe Frontend MVP Tasks

This checklist executes [`plan.md`](plan.md) against the canonical frontend and
backend specifications. Complete tasks in dependency order. Do not implement a
later task merely because a nearby file is already open.

## Execution Rules

- [x] Human approval of `plan.md` and this checklist recorded on 2026-08-09.
- Treat every numbered Task 0-15 as a macro/checkpoint, not as one implementation
  assignment. Implement exactly one unchecked lettered work unit (for example,
  Task 3B) per turn. Never combine adjacent units merely because they share a
  file.
- Before a work unit, read its parent task, the named dependency units, and only
  the relevant sections of `plan.md`, `README.md`, and the canonical backend
  specification. Inspect every listed file before editing it.
- The work unit's **Files** list is its allowed edit scope. If another production
  file is required, stop and update this checklist through review before editing
  it. Generated dependency lockfiles named by the unit are allowed outputs of
  the documented package-manager command.
- Start behavior units with the stated failing test. A unit is complete only when
  its **Done when** statement is true and every **Verify** command passes. Record
  the evidence, inspect `jj diff`, and stop; do not begin the next unit.
- Keep the working application buildable after every unit. A parent macro task is
  complete only after all of its lettered units and its parent acceptance criteria
  pass.
- Preserve unrelated working-copy changes and inspect `jj status` before and
  after each lettered work unit. Each work unit is one review-sized change.
- Start behavior changes with the narrowest failing test or fixture. Do not mark
  a checkbox until its stated verification has actually passed.
- Use `gleam add` for Gleam dependencies and Bun tooling for JavaScript test
  dependencies. Never hand-edit `manifest.toml`, `bun.lock`, or generated JS.
- Decode all network/browser data at its boundary. Do not log usernames, message
  text, cookies, raw frames, malformed payloads, or browser storage.
- Keep usernames, IDs, messages, and server errors text-safe. No HTML injection,
  raw DOM mutation, `innerHTML`, or string-built markup.
- Run Chromium Playwright tests through the non-interactive CLI with one worker
  while implementing. Use interactive/headed tooling only when explicitly
  requested or needed for a human diagnostic.
- Stop at every checkpoint for review. If the canonical backend contract and the
  implemented backend differ, reconcile documentation and fixtures before
  changing frontend behavior.
- For Lustre, Playwright, Canvas, cookie, or WebSocket APIs, use the official
  references linked from `plan.md` for the versions locked by Task 0. If the
  documented API cannot express the unit as written, stop and report the exact
  mismatch instead of inventing an FFI or adding a dependency.

## Work-unit handoff prompt

Use this prompt when assigning a unit to a smaller model:

```text
Implement only Task <ID> from tasks/todo.md. Read the execution rules, its parent
macro task, named dependencies, and the relevant contract sections first. Edit
only its Files list. Start with the stated failing test when behavior changes.
Meet Done when, run every Verify command, inspect jj diff/status, report evidence,
and stop without starting the next unit. If a contract, API, file-scope, or
dependency mismatch appears, stop and report it rather than guessing.
```

