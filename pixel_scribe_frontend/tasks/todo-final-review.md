
## Final Review Gate

- [ ] Every task acceptance criterion and checkpoint is checked with evidence.
- [ ] The frontend never keys identity, placement, message ownership, or bubbles
  by username.
- [ ] The camera targets only `self_id`, keeps that avatar centered, and never
  introduces synchronized coordinates, manual pan, or zoom into the MVP.
- [ ] The frontend never renders optimistic/offline messages or promises durable
  chat/session restoration.
- [ ] The WebSocket contract, limits, errors, and fixtures match the canonical
  backend specification.
- [ ] Essential behavior is semantic DOM, keyboard usable, safe as text, and
  responsive to 320px; Canvas remains supplementary.
- [ ] Renderer/browser/socket FFI boundaries are narrow, disposed, and tested;
  static scenes do not run continuously.
- [ ] No authentication, alternate room, movement, editor, game engine, Wasm,
  media, or new protocol field entered scope.
- [ ] Full Gleam, browser, staging, container, and real-backend checks pass.
- [ ] Code, security, accessibility, and simplification reviews are complete.
- [ ] Human approves the MVP for merge/release.
