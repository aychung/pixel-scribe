# AGENTS.md

## Project

- This is a Gleam backend for a virtual office.
- The MVP is real-time chat over WebSockets, served with Wisp.
- Users have no accounts or authentication; a cookie remembers their username.
- Chat history may be kept in memory and may be lost on restart.
- If persistence is added, prefer SQLite through `sqlight` for the MVP.
- Screen sharing and video sharing are future work.

## Working guidelines

- Favor the smallest implementation that satisfies the current MVP.
- Treat existing starter code as exploratory, not as an architectural contract.
- Validate all client-provided values; cookies and WebSocket messages are untrusted.
- Add focused tests for behavior changes and keep documentation aligned with scope.
- Do not introduce durable infrastructure, authentication, or future media features
  without an explicit requirement.
