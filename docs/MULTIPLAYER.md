# Multiplayer — design & plan

Goal: up to four people play one Spades match together, each on their
own phone (or browser tab), with bots filling any empty seats. The
single-player game keeps working exactly as before.

## 1. Architecture

```
┌──────────────── packages/spades_engine (pure Dart) ────────────────┐
│ models · engine · ai            (moved from mobile/lib/core)       │
│ session/  GameSession — authoritative table: MatchState + seats,   │
│           bot turns, trick hold, next-hand readiness, per-seat     │
│           TableView (hides other players' cards)                   │
│ protocol/ JSON messages (client ⇄ server)                          │
│ hub/      RoomHub — rooms, codes, lobby, seats, reconnects;        │
│           transport-agnostic (talks to a PeerConnection)           │
│ io_server.dart  dart:io WebSocket binding for RoomHub              │
│ bin/server.dart standalone server (Docker-able)                    │
└────────────────────────────────────────────────────────────────────┘
            ▲ same code runs in both places ▲
┌──── standalone server ────┐   ┌──── host phone (LAN) ─────────────┐
│ dart run bin/server.dart  │   │ app starts RoomHub on port 8080   │
└───────────────────────────┘   └───────────────────────────────────┘
            ▲ WebSocket (JSON)            ▲
┌──────────────────────── mobile app ────────────────────────────────┐
│ TableClient (interface the table UI reads)                          │
│  ├─ LocalTableClient  — in-process GameSession, you + 3 bots        │
│  └─ RemoteTableClient — WebSocket to a RoomHub, auto-reconnect      │
└─────────────────────────────────────────────────────────────────────┘
```

Key decisions:

- **Server-authoritative.** Only the session holds the deck and every
  hand. Each client receives a `TableView` for its own seat: its own
  cards, other seats' card *counts*, public bids/tricks/scores. No
  client can see or change what it shouldn't.
- **One engine, one table UI.** Single-player also runs through
  `GameSession` (in-process), so the rules, bot timing and the table UI
  are the same code path in both modes and share one test suite.
- **Two ways to connect, same protocol.** Host on this device (no
  infrastructure; friends on the same Wi-Fi join by IP + room code), or
  point every player at a standalone server (works over the internet;
  Docker image provided). The browser build can join but not host.
- **Seat-relative display.** Each player sees themselves at the bottom;
  the UI rotates absolute seats so the player to your left is drawn at
  West, etc.

## 2. Rules in multiplayer

- Partnerships stay South/North vs West/East; players pick seats in the
  lobby, empty seats become bots at start.
- The "final say" house rule (docs/RULES.md §3) generalizes: every
  *human whose partner is a bot* bids after that partner. Two human
  partners bid in normal clockwise order.
- After a hand, each connected human taps **Next hand**; the next hand
  deals once all of them are ready (bots and disconnected players never
  block).

## 3. Connection lifecycle

- `create` → server makes a 4-letter room code, the creator is host and
  sits South.
- `join` → takes the first open seat (partner seat first); in the lobby
  players can move to any open seat, the host can add/remove bots.
- `start` (host only) → empty seats filled with bots, match begins.
- Disconnects: the seat is held. If the player isn't back within a
  grace period (20 s) a bot plays for them ("autopilot") until they
  reconnect. Clients retry automatically with backoff and resume by
  their client id.
- Rooms with no connected humans are cleaned up after 10 minutes.

## 4. Protocol (JSON over WebSocket, one object per message)

Client → server: `create{name,clientId}`, `join{code,name,clientId}`,
`sit{seat}`, `setBot{seat,bot}`, `start`, `bid{bid}`, `play{card}`,
`ready`, `leave`.

Server → client: `room{…}` — a full snapshot (room code, host, seats and
occupants, your seat, started flag, and your `TableView` once the game
is on) sent after every change; `error{message}`.

Full snapshots instead of deltas keep clients stateless and make
reconnects trivial; a view is a few KB at most.

Every client action carries a `seq`; each snapshot echoes the last one
the server processed as `ack`. A client doesn't send another action
until its last one is acked (or answered with an error), so a double
tap or a burst of snapshots can never make it act on a stale view.

## 5. How to run it

See [mobile/README.md](../mobile/README.md#play-with-friends) for hosting
on a phone, running the standalone server (`dart run bin/server.dart`
or the Dockerfile in `packages/spades_engine`), and trying multiplayer
with several browser tabs on one computer.

## 6. Known limits

- A phone that hosts must keep the app in the foreground; if the OS
  suspends it, the room goes with it. Use a server for long games.
- Room codes (4 letters) are for convenience, not secrecy: on a public
  server anyone who guesses a code can join a room still in its lobby.
  Seats can't be taken over once the game starts — a returning player is
  recognized by a private per-device id that other players never see.
- The server caps parsed message size, but dart:io buffers a WebSocket
  message before that check; put a public server behind a reverse proxy
  that limits frame size (and run it with `--trust-proxy` so the
  wrong-code limit — 10 per minute per address — sees real client
  addresses). Players already in a room can always rejoin it.
- Hosting on this device isn't available in the browser build (browsers
  can't accept incoming connections); browsers can join or use a server.

## 7. Build steps (as built)

1. Extract `packages/spades_engine`; move engine + tests; app depends on
   it by path.
2. `GameSession` + `TableView` (+ JSON) with tests (fake clock).
3. Protocol + `RoomHub` with in-memory connection tests.
4. dart:io WebSocket server + `bin/server.dart` + real-socket test +
   Dockerfile.
5. App: `TableClient`, `LocalTableClient` (replaces GameController),
   table UI reads `TableView` with seat rotation.
6. App: `RemoteTableClient`, embedded host, Multiplayer + Lobby screens.
7. Review → fix → repeat; docs and platform permissions (Android
   INTERNET, iOS local network, cleartext `ws://` on LAN).

## 8. Testing

- Engine: rules tests (existing), session tests incl. hidden-info,
  autopilot, readiness; JSON round-trips.
- Hub: create/join/sit/bots/start/turn validation/reconnect/cleanup,
  host-only actions, malformed messages.
- Server: a real WebSocket match driven by scripted clients.
- App: widget tests for home/table/lobby; `RemoteTableClient` against
  an in-process `RoomHub`.
