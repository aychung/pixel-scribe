## Task 3: Implement trusted domain values, validation, and protocol codecs

**Description:** Define the frontend's trusted protocol types, mirror visible
backend validation, encode both client events, and decode every documented server
event at the network boundary. Additive fields and unknown future event types are
forward-compatible; malformed known events are not.

### Work units

- [x] **Task 3A — Define opaque protocol domain values.**
  - **Done when:** room, connection, and message IDs are opaque; presence, chat
    message, server-event, and error-event values have explicit fields; and only
    safe string conversion functions expose IDs for codecs/tests.
  - **Files:** `src/pixel_scribe_frontend/domain.gleam`,
    `test/pixel_scribe_frontend/domain_test.gleam`.
  - **Verify:** start with domain construction/equality tests, then run
    `gleam format --check src test`; `gleam build`; `gleam test`.
  - **Depends:** Task 0C.
- [x] **Task 3B — Implement username and multiline-message validation.**
  - **Done when:** username fixtures match the canonical contract and messages
    follow the exact LF allowance, control rejection, trimming, and
    1-500-grapheme rules in `plan.md`.
  - **Files:** `src/pixel_scribe_frontend/validation.gleam`,
    `test/pixel_scribe_frontend/validation_test.gleam`.
  - **Verify:** first add failing boundary fixtures for rejected
    CRLF/CR/`U+2028`/`U+2029`, accepted LF, tabs, C0/C1, DEL, emoji, and combining
    text; then run format, build, and `gleam test`.
  - **Depends:** Task 3A and the updated canonical backend message contract.
- [x] **Task 3C — Encode canonical client events.**
  - **Done when:** join and send encoders emit only the exact snake-case JSON
    fields for room `default`, using already trusted username/message values; each
    encoder measures its complete final UTF-8 JSON text frame and accepts 8,192
    bytes but rejects 8,193 bytes (or larger) before a send command can be emitted.
  - **Files:** `src/pixel_scribe_frontend/protocol.gleam`,
    `test/pixel_scribe_frontend/protocol_test.gleam`.
  - **Verify:** exact-string/golden tests for both events, including byte-heavy
    UTF-8/escaped values at 8,192 (accepted) and 8,193 (rejected) for both
    `join_room` and `send_message`; assert oversized results are not sendable;
    format, build, and `gleam test`.
  - **Depends:** Tasks 3A-3B.
- [x] **Task 3D — Decode and reject server frames.**
  - **Done when:** every documented server event and nullable error room decodes;
    additive fields and unknown future event types are tolerated; malformed known
    events fail without retaining raw payload text.
  - **Files:** `src/pixel_scribe_frontend/protocol.gleam`,
    `test/pixel_scribe_frontend/protocol_test.gleam`.
  - **Verify:** failing fixtures first for exact, additive, unknown, missing,
    wrong-type, nullability, XSS-like, and malformed cases; format, build, and
    `gleam test`; compare fields with the canonical backend spec.
  - **Depends:** Task 3C.

**Implementation notes:**

1. Define opaque room/connection/message IDs and explicit `Presence`,
   `ChatMessage`, `ServerEvent`, `ErrorEvent`, and decode-error types. Treat
   timestamps as server-provided RFC3339 strings unless a real display operation
   requires parsed time.
2. Encode exactly:
   `join_room(room_id="default", username)` and
   `send_message(room_id="default", text)` with snake-case fields and text JSON.
   Serialize the complete JSON text, encode it as UTF-8, and measure those bytes;
   accept frames up to 8,192 bytes, reject 8,193-byte frames, and return a local
   size failure so the caller can prevent the socket send while leaving the
   username/draft for inline feedback.
3. Decode `room_state`, `user_joined`, `user_left`, `message_sent`, and `error`.
   Require documented fields/types, allow `error.room_id` string or null, ignore
   additive fields, and return a distinct safely ignored value for unknown `type`.
4. For messages, allow LF; reject CR, `U+2028`, `U+2029`, every other C0/C1
   control, and DEL; trim; then enforce `1-500` Unicode grapheme clusters,
   counting each retained LF. Mirror the backend's validation order and fixtures.
   Do not add a Unicode package without review.
5. Cover XSS-like strings as ordinary text data. No decoder failure may include
   raw payload content in an application-visible/loggable value.

**Acceptance criteria:**

- [x] Every documented event has a passing exact fixture, and client encoders
  produce the canonical JSON shape for `default` and never emit an oversized
  final UTF-8 frame for either client event.
- [x] Missing/wrong fields, malformed JSON, invalid nullability, and malformed
  known events fail safely; additive fields and unknown event types do not.
- [x] Username/message validation matches backend fixtures at empty, maximum,
  over-limit, combining-character, emoji, whitespace, rejected
  CRLF/CR/`U+2028`/`U+2029`, accepted LF, tab, C0/C1, and DEL boundaries.

**Verification:**

- [x] Start with failing fixture/validation tests, then implement the codecs.
- [x] `gleam format --check src test`
- [x] `gleam build`
- [x] `gleam test`
- [x] Compare fixture field names and error inventory line by line with the
  canonical backend specification and current backend protocol tests.

**Dependencies:** Task 0 and the updated canonical backend message contract.

**Files likely touched:**

- `src/pixel_scribe_frontend/domain.gleam`
- `src/pixel_scribe_frontend/validation.gleam`
- `src/pixel_scribe_frontend/protocol.gleam`
- `test/pixel_scribe_frontend/validation_test.gleam`
- `test/pixel_scribe_frontend/protocol_test.gleam`

**Estimated scope:** Medium, 5 files.
