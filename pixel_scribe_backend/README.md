# Pixel Scribe Backend

Pixel Scribe is a Gleam backend for a virtual office. The long-term product may
support chat, screen sharing, and video, while the MVP focuses on real-time chat
over WebSockets.

## MVP

- Serve HTTP and WebSocket connections with Wisp.
- Let visitors choose a username without creating an account.
- Remember the username in a browser cookie.
- Send and receive chat messages in real time.
- Keep chat history ephemeral; losing it when the server restarts is acceptable.

SQLite through `sqlight` may be added for local chat persistence, but durable
history is not required for the MVP. Authentication, screen sharing, and video
sharing are outside the initial scope.

The project is in an early exploratory stage, so its data model and protocol
details will be defined as the MVP takes shape.
