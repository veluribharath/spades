# Spades (Flutter app)

Partnership Spades for Android, iOS and the web — against bots, or with
friends on their own devices. Rules: [docs/RULES.md](../docs/RULES.md).
Multiplayer design: [docs/MULTIPLAYER.md](../docs/MULTIPLAYER.md).

The rules engine, bots, game sessions and the multiplayer server live in
the pure-Dart package [`packages/spades_engine`](../packages/spades_engine),
shared by this app and the standalone server.

## Run

```bash
cd mobile
flutter pub get
flutter run            # pick a device: iOS simulator, Android, Chrome...
```

## Play with friends

**Same Wi-Fi, no setup (phones/tablets/desktop):** one person taps
*Play with friends → Host a game → On this device → Create room*. The
room screen shows an address (e.g. `192.168.1.20`) and a 4-letter code.
Everyone else taps *Join a game*, enters that address and code. Keep the
app open on the host device — it is the server.

**Through a server (works over the internet, and in the browser):** run
the server somewhere everyone can reach:

```bash
cd packages/spades_engine
dart pub get
dart run bin/server.dart            # ws://0.0.0.0:8080/, or --port N
# or: docker build -t spades-server . && docker run -p 8080:8080 spades-server
```

Then choose *Host a game → On a server* with that address (e.g.
`localhost`, `192.168.1.20`, or `wss://spades.example.com` behind TLS),
and friends join with the same address plus the room code.

### Trying multiplayer alone on one computer

```bash
# terminal 1
cd packages/spades_engine && dart run bin/server.dart
# terminal 2
cd mobile && flutter run -d chrome
```

In the first tab: *Play with friends → On a server → `localhost` →
Create room*. Open the same app URL in a second tab (a new tab, or a
duplicated one — each tab is its own player), *Join a game* with
`localhost` and the code. Start the game from the first tab; bots fill
the other seats.

## Test

```bash
cd packages/spades_engine && dart test   # rules, sessions, hub, real sockets
cd mobile && flutter test                # app state, multiplayer client, widgets
```
