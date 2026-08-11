# Reconcile the `room_unavailable` connection matrix

**Description:** Reconcile the finalized WebSocket error contract with the
implemented dead-room join path before frontend Task 6 adds native socket
integration. The backend currently emits a non-recoverable `room_unavailable`
error from `AwaitingJoin` when the directory resolves a dead room handle, while
`docs/mvp-backend-spec.md` lists that error only for `Joining` and `Joined`.

The intended resolution is to document the existing fail-closed behavior:
`AwaitingJoin` may emit `room_unavailable` with the validated requested room,
send the error, and then close. This does not change the wire shape, error
metadata, room scope, or MVP feature scope.

## Acceptance criteria

- [x] The canonical Task 7 error/close matrix includes the implemented
  `AwaitingJoin` dead-room path for `room_unavailable`.
- [x] A focused backend connection test freezes its room context,
  non-recoverability, error-before-close order, and terminal socket behavior.
- [x] Frontend protocol fixtures represent the reconciled context,
  recoverability, and close policy before native WebSocket work begins.
- [x] Backend and frontend task documentation no longer disagree with the
  implemented behavior.

## Files likely touched

- `docs/mvp-backend-spec.md`
- `src/pixel_scribe_backend/connection.gleam`
- `test/pixel_scribe_backend/connection_test.gleam`
- `../pixel_scribe_frontend/test/pixel_scribe_frontend/protocol_test.gleam`
- `../pixel_scribe_frontend/tasks/plan.md` only if its summarized policy needs
  clarification

## Verification

From `pixel_scribe_backend/`:

```sh
gleam format --check src test
gleam build
gleam test
```

From `pixel_scribe_frontend/`:

```sh
gleam format --check src test
gleam build
gleam test
```

Review the complete diff and keep this reconciliation in its own Jujutsu
revision before resuming frontend Task 6B. The complete diff was reviewed and
is ready as its own revision.
