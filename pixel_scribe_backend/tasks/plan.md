# Implementation Plan: Pixel Scribe Backend MVP

## Status

Draft for review. The product specification is approved; implementation must not
begin until this plan is approved.

## Source of Truth

- Product and architecture: `docs/mvp-backend-spec.md`
- Execution checklist: `tasks/todo.md`
- Existing source code is exploratory and does not constrain this plan.

## Overview

Build a single-instance Gleam/Wisp backend that serves static frontend assets and
one room-aware WebSocket endpoint. The MVP starts only the `default` room, tracks
presence by server-issued connection IDs, retains the latest 50 messages in
memory, and supports up to 50 joined connections. Authentication, databases,
movement, media, and multiple active rooms remain out of scope.

## Architecture Decisions

- Wisp handles HTTP concerns and adapts to the supervised Mist server.
- JSON codecs and boundary validation are separate from trusted domain types.
- A `RestForOne` root supervisor starts the room directory, room factory, then web
  server in dependency order.
- The room factory creates and registers `default` before HTTP readiness.
- The directory owns string room-ID lookup; the factory owns room lifecycles.
- One room actor serializes presence and chat state for each room.
- Mist's WebSocket process acts as the connection actor and is the only socket
  writer.
- Room and connection processes monitor each other for idempotent cleanup and
  failure recovery.
- State is intentionally in memory; no database abstraction or dependency is
  introduced.

## Dependency Graph

```text
Clean, buildable starter baseline + direct dependencies
├──► Wisp/Mist compatibility baseline
│       └──► HTTP/static delivery
└──► Validated domain types
        ├──► JSON protocol codecs
        └──► Room actor
                └──► Room directory
                        └──► Room factory + root supervision

Wisp/Mist baseline + JSON codecs + room supervision
└──► WebSocket join/presence
        ├──► Chat/history/rate limit
        └──► Liveness/failure recovery
                    └──► MVP integration
```

## Task List

### Phase 1: Contract and platform foundation

- [ ] Task 0A: Detach and delete the broken four-file runtime chain, then stop for
  review.
- [ ] Task 0B: Delete the orphaned configuration module, then stop for review.
- [ ] Task 0C: Delete the orphaned user registry, then stop for review.
- [ ] Review checkpoint: Approve Tasks 0A-0C and confirm the package builds.
- [ ] Task 0D: Delete the two remaining chat placeholders, then stop for review.
- [ ] Task 0E: Add the minimal Gleam test runner, then stop for review.
- [ ] Task 0F: Add Wisp and `gleam_json` through Gleam tooling, then stop for
  review.
- [ ] Task 0 checkpoint: Approve all six revisions and the cumulative green
  baseline.
- [ ] Task 1: Prove the Wisp/Mist platform baseline.
- [x] Task 2: Define validated domain types.
- [x] Task 3: Implement the typed WebSocket protocol codecs.

### Checkpoint: Contract foundation

- [ ] Wisp and the locked Mist version have a documented compatible setup.
- [ ] All public payload variants have round-trip and rejection tests.
- [ ] Format, build, and tests pass.
- [ ] Review contract implementation before shared state is added.

### Phase 2: Supervised room subsystem

- [ ] Task 4: Implement the authoritative room actor.
- [ ] Task 5: Implement the monitored room directory.
- [ ] Task 6: Start rooms through the factory and root supervision tree.

### Checkpoint: Room subsystem

- [ ] Factory startup registers `default` before reporting readiness.
- [ ] Presence, capacity, history, and room restart tests pass.
- [ ] Directory replacement cannot be undone by a delayed monitor notification.
- [ ] Format, build, and tests pass.

### Phase 3: Real-time user flows

- [ ] Task 7: Deliver WebSocket join and presence end to end.
- [ ] Task 8: Deliver chat, bounded history, and rate limiting end to end.
- [ ] Task 9: Add connection liveness and supervised failure recovery.

### Checkpoint: Real-time MVP

- [ ] Two clients can join, observe presence, and exchange ordered messages.
- [ ] Reconnect, room failure, duplicate labels, and disconnect cleanup work.
- [ ] The 51st join, invalid input, mismatched rooms, and spam are bounded.
- [ ] Format, build, and tests pass.

### Phase 4: Delivery and acceptance

- [ ] Task 10: Harden HTTP configuration and static delivery.
- [ ] Task 11: Integrate frontend artifacts and run MVP acceptance checks.

### Checkpoint: Complete

- [ ] The compiled frontend and WebSocket are served from one production origin.
- [ ] Security headers, origin policy, health check, and static 404 behavior pass.
- [ ] Full automated suite and manual two-client smoke test pass.
- [ ] Documentation matches the delivered commands and behavior.
- [ ] Ready for code review; implementation remains single-instance and ephemeral.

## Verification Strategy

Every task runs the narrowest relevant tests plus the project-wide checks:

```sh
gleam format --check src test
gleam build
gleam test
```

Actor and protocol behavior should be tested without a network where possible.
Integration tests cover WebSocket lifecycle and supervision boundaries. The final
checkpoint adds a running-server smoke test with two independent clients.

## Parallelization Opportunities

- Tasks 0A-0F must run sequentially, with a human review between revisions. The
  Task 0 checkpoint must finish before any later task starts so all feature work
  begins from a clean, buildable baseline with Wisp and `gleam_json` declared
  directly.
- After Task 0, Tasks 1 and 2 are logically independent.
- After Task 2, Task 3 and the pure state portion of Task 4 can proceed separately
  if their domain-type contract is frozen first.
- Tasks 5 and the room actor's pure tests can proceed separately after opaque room
  handles are agreed.
- Tasks 7–9 must remain coordinated because they share connection state and the
  WebSocket integration tests.
- Task 11 depends on the frontend package's finalized output contract.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Adding Wisp or `gleam_json` changes the dependency graph | High | Add both through Gleam tooling in Task 0, review deterministic manifest changes, then prove Wisp/Mist compatibility in Task 1 |
| Mist selector or close behavior differs from the architecture assumption | High | Prove custom-message selection and close cleanup in the first WebSocket slice |
| Factory bootstrap leaves the app ready without `default` | High | Make registration part of child startup and failure-test the entire path |
| Room/connection monitor races create duplicate leave events or stale handles | High | Use PID-matched, idempotent cleanup with adversarial actor tests |
| Unicode grapheme counting needs another dependency | Medium | Verify standard-library support first; request approval before adding a package |
| Slow or malicious clients pressure mailboxes | Medium | Bound event size, join time, rate, room capacity, and keep socket writes out of the room actor |
| No authentication permits room takeover or spam | Accepted | Document exposure and rely on external access control for private deployments |
| Frontend build output is not finalized | Medium | Keep a stable `priv/public` input contract and finalize one reproducible copy command in Task 11 |

## Non-Goals

- Authentication or authorization.
- SQLite or any durable state.
- Multiple active room IDs, room management endpoints, or room discovery.
- Avatar position or movement.
- Delivery acknowledgements, retries, or offline messages.
- Multiple backend instances or distributed room coordination.
- Voice, video, or screen sharing.

## Remaining Implementation-Time Decisions

No product decisions are open. These technical selections are resolved inside the
named tasks and must stay within the approved specification:

- The exact compatible Wisp and `gleam_json` versions resolved and recorded in
  Task 0, with Wisp/Mist adapter compatibility proved in Task 1.
- The complete error behavior matrix, refined and documented with its contract
  tests during Tasks 3 and 7.
- A dependency-free server-lifetime ID representation, if available; adding an ID
  package still requires approval.
- The exact frontend output path and repository-level copy command in Task 11.
