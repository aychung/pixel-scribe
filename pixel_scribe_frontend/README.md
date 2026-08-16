# Pixel Scribe Frontend

Pixel Scribe is a client-side Lustre application for a small virtual office. The
MVP presents a pixel-art office on an HTML5 canvas and a room chat beside it.
Gleam compiles the application to JavaScript; the backend serves the built assets
and provides a JSON WebSocket API.

Lustre runs only as a browser SPA. The frontend does not use Lustre server
components, server-side rendering, or Lustre's DOM-patch WebSocket protocol. The
existing backend remains the authority for the JSON `/ws` contract.

The foundation and real-time chat slices are implemented: the browser-only
Lustre shell, protocol codecs, pure connection state machine, username
preference, same-origin native WebSocket, joined presence workspace,
accepted-message chat, reconnect recovery, the renderer-independent office world,
camera, local placement, draw data, and the Canvas renderer are in place. The
baseline office assets are original with recorded provenance; the renderer uses
the v2 tile atlas and all 32 cells of the avatar atlas. Task 11F human
visual/provenance approval and real-backend browser acceptance remain open in
later MVP checkpoints.

## MVP

The frontend must let a visitor:

1. Choose a display username, with a previous choice prefilled from a
   frontend-owned cookie.
2. Join the built-in `default` office.
3. See the current room participants and recent chat history.
4. Send and receive plain-text chat messages in real time.
5. Keep the pixel-art office visible while using chat on desktop and mobile.
6. Understand connecting, reconnecting, validation, rate-limit, room-full, and
   unavailable states.

Authentication, multiple active rooms, server-synchronized avatar coordinates,
movement, durable chat, offline delivery, voice, video, and screen sharing are
outside the MVP. The scene state and placement are local to each browser; no
backend event currently drives objects or coordinates on the canvas.

## Basic UX flow

1. `GET /` loads the app. Before joining, show a small username form over or
   beside a non-interactive preview of the office. Prefill the last username from
   the browser cookie, but do not treat it as identity.
2. Trim and validate the username using the same visible limits as the backend:
   1–32 Unicode grapheme clusters, with no control characters or line breaks.
   Preflight the complete `join_room` JSON text frame before opening a socket.
3. On submit, persist the preference, open the same-origin `GET /ws` WebSocket,
   and show a clear connecting state. When the socket opens, immediately send
   one `join_room` event for `default`; the server requires a join within 10
   seconds.
4. Do not enable chat until `room_state` arrives. That snapshot establishes the
   current connection ID, participant list, and up to 50 recent messages.
5. Once joined, show the office canvas and chat workspace. The chat area contains
   connection status, a participant list/count, the message log, validation or
   connection feedback, and the composer.
   The office header exposes keyboard-usable `−`, zoom percentage/reset, and `+`
   controls; zoom keeps the current browser's avatar centered.
   Use a multiline composer: Enter sends, Shift+Enter inserts a line break, and
   an Enter key event must not send while an input-method composition is active.
6. Update presence from `user_joined` and `user_left`. Append an accepted message
   only when `message_sent` arrives, including messages sent by this client; do
   not optimistically create a second local copy.
7. Keep the message draft on connection loss, disable sending, announce the
   reconnecting state, and retry with capped exponential backoff plus jitter. Do
   not queue and automatically replay chat messages: the protocol has no delivery
   acknowledgement or idempotency key.
8. After reconnecting, send a new `join_room`. Replace room state from the new
   snapshot, accept the new `self_id`, and deduplicate snapshot/live overlap by
   `message_id`. Reconnection is a new presence, not session restoration.
9. Show recoverable errors next to the relevant form while keeping the socket
   usable. For a non-recoverable error, stop the joined UI and offer an explicit
   retry or return to the username form as appropriate.

Chat history is in memory and can disappear after a backend restart. The UI must
not promise persistence.

## Responsive layout

Use semantic HTML for controls, status, participants, and chat. Canvas pixels are
not a substitute for accessible DOM content.

- Desktop (`>= 768px`): fill `100dvh` with two columns. Chat is a fixed-width
  right rail (initial token: `22rem`); the canvas region takes the remaining
  width with `minmax(0, 1fr)`.
- Mobile (`< 768px`): use two rows. The canvas remains on top and chat becomes a
  bottom panel sized to leave both regions useful. Use dynamic viewport units so
  browser chrome and the software keyboard do not hide the composer.
- The chat log scrolls independently. Keep the composer visible at the bottom of
  its panel and preserve a sensible canvas minimum size.
- Verify at 320, 768, 1024, and 1440 CSS pixels, in portrait and landscape.
- Respect safe-area insets on devices with notches or home indicators.

The initial `22rem` rail and `768px` layout breakpoint are working defaults, not
backend constraints. Keep the rail width as a named CSS custom property; the
native media query is the single source of truth for the layout breakpoint.

## Frontend/backend contract

The source of truth is the backend
[MVP specification](../pixel_scribe_backend/docs/mvp-backend-spec.md). It is
approved, and its backend connection/error matrix is finalized. Keep frontend
codecs and contract tests aligned with it.

### HTTP

| Request | Contract |
| --- | --- |
| `GET /` | Compiled frontend entry document |
| `GET /ws` | Same-origin WebSocket upgrade |
| `GET /healthz` | Backend process health; not application state |
| Static asset path | File from the backend's configured `priv/public` tree |
| Unknown path | `404` |

Use `wss:` when the page uses HTTPS and `ws:` otherwise. Production allows only
the application's own origin. The frontend and socket are served from the same
origin in production.

### Wire format

- Each frame is one UTF-8 JSON object with a string `type` discriminator.
- Event and field names are `snake_case`.
- Every room-scoped event has top-level `room_id`.
- Before sending either `join_room` or `send_message`, serialize the complete
  JSON object and measure the resulting UTF-8 JSON text frame. Accept exactly
  `8,192` bytes or fewer; reject `8,193` bytes before sending. Client events are
  text frames only; do not send binary.
- Unknown client fields are ignored for forward compatibility.
- Treat IDs as opaque strings and timestamps as server-generated RFC 3339 UTC.
- Decode server data at the boundary. Tolerate additive optional fields and
  safely ignore unknown future server event types.

### Client to server

The first and only successful join on a socket is:

```json
{"type":"join_room","room_id":"default","username":"Ada"}
```

After `room_state`, send chat with:

```json
{"type":"send_message","room_id":"default","text":"Hello!"}
```

The `room_id` must always be `default` in the MVP and must match the joined room.
The username cannot be changed without opening a new connection.

### Server to client

```text
Presence    = { connection_id: String, username: String }
ChatMessage = {
  message_id: String,
  sender_id: String,
  username: String,
  text: String,
  sent_at: RFC3339 String
}
```

| Event | Required fields | Frontend effect |
| --- | --- | --- |
| `room_state` | `room_id`, `self_id`, `users[]`, `messages[]` | Enter joined state and replace the room snapshot |
| `user_joined` | `room_id`, `user` | Add the presence by `connection_id` |
| `user_left` | `room_id`, `connection_id` | Remove only that connection ID |
| `message_sent` | `room_id`, `message` | Append once by `message_id`; the sender also receives it |
| `error` | `room_id` (`String` or `null`), `code`, `message`, `recoverable` | Present safe feedback and follow recoverability |

Usernames are not unique. Never key participants or ownership by username; use
`connection_id` and compare authorship with `self_id`.

### Validation and limits

| Value | Rule |
| --- | --- |
| Username | Trim; 1–32 Unicode grapheme clusters; no controls or line breaks; duplicates, spaces, and emoji allowed |
| Room ID | `[a-z0-9][a-z0-9_-]{0,63}`; only `default` is supported |
| Message | Allow LF; reject CR, `U+2028`, `U+2029`, every other C0/C1 control, and DEL; trim; 1–500 Unicode grapheme clusters including LF; plain text only |
| Client event frame | The final UTF-8 JSON text frame for both `join_room` and `send_message` is at most 8,192 bytes; 8,192 is accepted and 8,193 is rejected |
| Room capacity | 50 simultaneous presences |
| Snapshot history | Latest 50 accepted messages |
| Chat rate | Burst of 5, then refill 1 message per second per connection |

Client validation improves feedback but never replaces server validation. If the
final encoded `join_room` or `send_message` frame exceeds 8,192 bytes, keep the
username or draft, show inline feedback, and emit no frame. This local rejection
prevents the backend's terminal `invalid_event` response. Render all usernames,
messages, and error text as text, never as HTML.

LF (`U+000A`) is the only control character retained in a normalized message.
CRLF, bare CR, Unicode line separator (`U+2028`), Unicode paragraph separator
(`U+2029`), tabs, NUL, escape, backspace, DEL, and all other C0/C1 controls are
invalid. Each accepted LF counts toward the 500-grapheme limit. Preserve accepted
line breaks in the DOM chat log. Canvas bubbles may visually truncate to three
lines without changing the full DOM message.

### Error handling

| Code | Recoverable | Expected UX |
| --- | --- | --- |
| `invalid_event` | No | Stop the connection and report a protocol failure |
| `join_required` | Yes | Keep the socket; prevent chat until joined |
| `already_joined` | Yes | Keep the current joined identity; do not join again |
| `invalid_room_id` | Yes | Return to/focus the room choice when that UI exists |
| `room_not_found` | Yes | Explain that the selected office is unavailable |
| `room_mismatch` | Yes | Treat as a client defect; retain the joined room |
| `room_unavailable` | No | Reconnect to resolve the restarted room |
| `invalid_username` | Yes | Show the message at the username field |
| `invalid_message` | Yes | Show the message at the composer |
| `rate_limited` | Yes | Keep the draft usable and briefly throttle sending |
| `room_full` | No | Return to a blocked join state with retry available |

The backend sends the structured error and then closes after `invalid_event`,
`room_full`, and `room_unavailable`. Recoverable errors leave the backend phase
unchanged. The frontend contract-tests each code's documented room context,
recoverability, phase, and close policy so changes are visible.

Backend recoverability describes the server's phase and whether it closes the
socket. The built-in-room-only frontend deliberately closes and resets after
`invalid_username`, and deliberately closes into its unavailable-office state
after `invalid_room_id` or `room_not_found`; these are client UX policies, not
changes to the wire contract. For `room_unavailable`, the frontend accepts the
backend's documented close and lets the reconnect state machine schedule
backoff.

## Technology direction

### Lustre client-side SPA

`gleam.toml` targets JavaScript. Build one client-side SPA with
`lustre.application(init, update, view)` and mount it onto `#app` with
`lustre.start`. Use the full application constructor rather than `lustre.simple`
because the app requires long-lived WebSocket, timer, cookie, DOM-measurement,
and canvas effects.

Follow Lustre's Model–View–Update structure:

- `Model` owns the connection phase, joined identity, participants, messages,
  draft, errors, and renderer-facing scene state.
- `Msg` represents user actions, decoded server events, socket lifecycle events,
  reconnect timers, and relevant browser/renderer events.
- `update` performs deterministic state transitions and returns
  `#(Model, Effect(Msg))`.
- `view` renders the join screen, status, participants, chat, composer, and the
  canvas element as accessible HTML.
- Lustre effects own WebSocket setup and cleanup, cookies, timers, focus or DOM
  measurements, and canvas renderer commands.

Prefer ordinary view functions. Do not introduce stateful Lustre components
unless a genuinely complex widget needs its own isolated update loop.

The planned runtime dependencies are `lustre` and `gleam_json`. Use the official
`lustre_dev_tools` as a development dependency for the local server, HTML entry
generation, asset copying, and production bundle. Let `gleam add` resolve
compatible versions and commit the resulting manifest.

### WebSocket and browser effects

Implement the contracted JSON connection as a custom Lustre effect over the
browser's native WebSocket API. The effect dispatches typed lifecycle and payload
messages into `update`; protocol code decodes each server frame before it can
enter the model. Keep reconnect policy in application state so the client never
automatically replays offline chat.

Use small JavaScript externals only where browser bindings are required, such as
WebSocket, cookies, `ResizeObserver`, `requestAnimationFrame`, and Canvas 2D.
Keep externals behind narrow typed Gleam modules and test each boundary. Lustre,
not handwritten DOM mutation, owns the application HTML.

### Canvas 2D first; WebAssembly only after profiling

Start with Canvas 2D driven by Gleam-compiled JavaScript. Gleam currently compiles
to Erlang or JavaScript, not WebAssembly, and generated JavaScript is not a useful
drop-in input for conversion to Wasm. WebAssembly also cannot remove the
JavaScript/browser boundary needed to call Canvas and DOM APIs.

Create a small renderer interface now (`init`, `resize`, `render`, `dispose`) so
its implementation can change later. In the JavaScript implementation:

- use `requestAnimationFrame` only while a redraw is needed;
- render at device-pixel-ratio-aware dimensions and resize with the container;
- disable image smoothing and use integer coordinates for crisp pixel art;
- cache sprites/static layers, avoid allocations in the frame loop, and redraw
  only dirty layers when practical;
- keep scene/state calculation separate from Canvas calls so it can be profiled.

Consider a Wasm module only when measurements on representative desktop and
mobile devices show a CPU-bound hot path, such as procedural generation, large
pixel filters, pathfinding, or simulation. Implement that isolated core in a
language with a supported Wasm target and call it from the existing JavaScript
renderer bridge. Canvas call overhead itself is unlikely to improve by moving
only the surrounding loop to Wasm.

References:

- [Lustre client application API](https://lustre.hexdocs.pm/lustre.html)
- [Lustre managed effects](https://lustre.hexdocs.pm/lustre/effect.html)
- [Lustre development tools](https://hexdocs.pm/lustre_dev_tools/)
- [Gleam compiler targets](https://gleam.run/command-line-reference/)
- [Gleam JavaScript externals](https://gleam.run/documentation/externals/)
- [MDN Canvas optimization guide](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API/Tutorial/Optimizing_canvas)
- [MDN WebAssembly concepts](https://developer.mozilla.org/en-US/docs/WebAssembly/Guides/Concepts)

## Proposed package structure

```text
pixel_scribe_frontend/
├── src/
│   ├── pixel_scribe_frontend.gleam      Browser entry point
│   └── pixel_scribe_frontend/
│       ├── model.gleam                  Application and connection state
│       ├── update.gleam                 Pure state transitions and commands
│       ├── runtime.gleam                Command and socket-effect interpreter
│       ├── protocol.gleam               JSON wire types and codecs
│       ├── socket.gleam                 WebSocket Lustre effects
│       ├── socket_ffi.mjs               Native WebSocket boundary
│       ├── view.gleam                   Lustre HTML view functions
│       ├── canvas.gleam                 Canvas Lustre effects
│       ├── canvas_ffi.mjs               Canvas renderer boundary
│       └── browser_ffi.mjs              Cookies and small browser bindings
├── assets/
│   ├── styles.css
│   └── pixel-art/                       Source sprites and scene assets
├── test/
│   └── pixel_scribe_frontend/
├── README.md
└── AGENTS.md
```

The official Lustre development tools generate the HTML entry and browser bundle,
copy `assets/`, and write to `dist/` by default. From the repository root, the
implemented `./scripts/build_frontend.sh` staging command cleans and validates
that artifact set, then copies it into `pixel_scribe_backend/priv/public`;
generated output remains uncommitted. This staging step does not constitute
Task 14 or full delivery acceptance.

Once source and tests exist, the minimum Gleam checks are expected to be:

```sh
gleam format --check src test
gleam build
gleam test
gleam run -m lustre/dev build
```

Run `gleam run -m lustre/dev start` for the local frontend development server.
When frontend and backend use different development origins, point the WebSocket
effect at the explicitly configured backend URL and allow the frontend origin in
the backend development configuration. Production continues to use `/ws` on the
page's origin.

Also add browser-level checks for keyboard use, reconnect behavior, WebSocket
contract fixtures, and responsive layouts before calling the frontend MVP done.

## Remaining checkpoint decisions

- Task 6 adopts the backend's finalized error room context, close order, and
  post-error connection phase after backend Task 7 updates the canonical spec.
- Task 11 requires human approval of the visual direction, palette, typography,
  source pixel-art assets, and asset provenance.
- Task 14 coordinates the reproducible frontend staging and container-delivery
  policy with the backend. Generated output remains uncommitted unless separately
  approved.
