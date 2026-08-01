# pixel_scribe

A browser-based virtual office application built with Gleam.
The frontend compiles to JavaScript and renders a pixel-art office using HTML5 Canvas.
The backend runs on the BEAM and manages connected users, presence, and real-time text chat.

## MVP

The initial version supports:

- Entering a username without authentication
- Joining a shared virtual office
- Displaying connected users as fixed avatars
- Assigning each avatar a random position
- Sending and receiving text messages
- Showing messages in a chat panel
- Showing temporary speech bubbles near avatars

Avatar movement, accounts, customization, voice chat, screen sharing, and video are outside the MVP scope.

## Repository Structure
.
├── frontend/
│   ├── gleam.toml
│   ├── src/
│   └── test/
├── backend/
│   ├── gleam.toml
│   ├── src/
│   └── test/
├── shared/
│   ├── gleam.toml
│   ├── src/
│   └── test/
└── README.md

### frontend

Gleam code compiled to JavaScript and executed in the browser.

Responsibilities include:

Username entry
WebSocket connection management
Canvas rendering
Avatar and speech-bubble rendering
Chat interface
Client-side application state


### backend

Gleam code running on the BEAM.

Responsibilities include:

Serving the WebSocket endpoint
Tracking connected users
Assigning session IDs and avatar positions
Broadcasting presence events
Validating and broadcasting chat messages
Removing disconnected users
Serving frontend assets later


### shared

Optional Gleam package containing code used by both targets.

Suitable shared code includes:

API message types
JSON encoders and decoders
User and chat data types
Validation rules
Protocol constants

The shared package should avoid JavaScript-specific or BEAM-specific dependencies.


## Communication Protocol

The application will primarily use WebSockets for real-time communication.

- Example client events:
  - `join`
  - `send_message`

- Example server events:
  - `room_state`
  - `user_joined`
  - `user_left`
  - `message_sent`
  - `error`

The exact payload formats should be defined as shared Gleam types and serialized as JSON.

## Development

Each directory is an independent Gleam package.

Run commands from the relevant package directory:

```
cd backend
gleam run

cd frontend
gleam build
```

Run tests with:

```
gleam test
```

Exact frontend bundling and backend startup commands will be added once the browser tooling and server framework are selected.

## Architecture Principles
- The backend is authoritative for shared room state.
- The frontend owns rendering and local UI state.
- API contracts should be explicitly typed.
- Client-provided usernames and messages must be validated.
- MVP state may remain in memory.
- Target-specific code should remain outside the shared package.

## Planned Development Order
1. Define shared domain and WebSocket message types
2. Implement backend room state
3. Implement WebSocket connection and join handling
4. Implement presence and chat broadcasting
5. Add protocol and room-state tests
6. Build the frontend connection layer
7. Build the chat interface
8. Render the office, avatars, and speech bubbles


## Future Features

Possible future additions include:

- User accounts and authentication
- Persistent profiles
- Avatar customization
- Avatar movement
- Multiple rooms
- Voice and video chat
- Screen sharing
- Persistent message history

