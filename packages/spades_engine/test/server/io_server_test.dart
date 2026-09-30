@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:spades_engine/io_server.dart';
import 'package:spades_engine/spades_engine.dart';
import 'package:test/test.dart';

/// A scripted player on a real WebSocket.
class SocketPlayer {
  SocketPlayer._(this.socket, this.clientId) {
    socket.listen((data) {
      final message = ServerMessage.decode(data as String);
      if (message is RoomSnapshot) {
        room = message;
        _act();
      } else if (message is ErrorMessage) {
        errors.add(message.message);
      }
      _updates.add(null);
    });
  }

  static Future<SocketPlayer> connect(int port, String clientId) async =>
      SocketPlayer._(
        await WebSocket.connect('ws://127.0.0.1:$port/'),
        clientId,
      );

  final WebSocket socket;
  final String clientId;
  RoomSnapshot? room;
  final List<String> errors = [];
  final _updates = StreamController<void>.broadcast();
  bool autoplay = false;
  int _seq = 0;

  void send(ClientMessage m) => socket.add(m.encode(seq: ++_seq));

  Future<void> until(bool Function() condition) async {
    if (condition()) return;
    await _updates.stream
        .firstWhere((_) => condition())
        .timeout(const Duration(seconds: 30));
  }

  void _act() {
    final v = room?.view;
    // Only act on a view that already reflects our last action.
    if (!autoplay || v == null || room!.ack < _seq) return;
    if (v.isMyBidTurn) {
      send(
        PlaceBid(
          chooseBotBid(
            hand: v.hand,
            config: v.config,
            isFirstBidOfHand: v.isFirstBid,
            teamScore: 0,
            opponentScore: 0,
            maxBid: v.maxBid,
          ),
        ),
      );
    } else if (v.isMyPlayTurn) {
      send(PlayCard(v.legalCards.first));
    } else if (v.phase == HandPhase.complete && !v.matchOver && !v.iAmReady) {
      send(const ReadyForNextHand());
    }
  }
}

void main() {
  late SpadesServer server;

  setUp(() async {
    server = await SpadesServer.bind(
      address: InternetAddress.loopbackIPv4,
      port: 0,
      hub: RoomHub(random: Random(1), timing: const SessionTiming.instant()),
    );
  });

  tearDown(() => server.close());

  test('health check', () async {
    final client = HttpClient();
    final response = await (await client.get(
      '127.0.0.1',
      server.port,
      '/health',
    )).close();
    expect(response.statusCode, 200);
    client.close();
  });

  test('two players finish a match over real sockets', () async {
    final alice = await SocketPlayer.connect(server.port, 'alice-socket');
    alice.send(const CreateRoom(name: 'Alice', clientId: 'alice-socket'));
    await alice.until(() => alice.room != null);

    final bob = await SocketPlayer.connect(server.port, 'bob-socket-1');
    bob.send(
      JoinRoom(code: alice.room!.code, name: 'Bob', clientId: 'bob-socket-1'),
    );
    await bob.until(() => bob.room != null);
    expect(bob.room!.yourSeat, Seat.north);

    alice.autoplay = bob.autoplay = true;
    alice.send(const StartGame());
    await alice.until(() => alice.room?.view?.matchOver ?? false);
    await bob.until(() => bob.room?.view?.matchOver ?? false);

    expect(alice.room!.view!.history, hasLength(13));
    expect(bob.room!.view!.teamScores, alice.room!.view!.teamScores);
    expect(alice.errors, isEmpty);
    expect(bob.errors, isEmpty);
    await alice.socket.close();
    await bob.socket.close();
  });

  test('a dropped socket shows as disconnected to the others', () async {
    final alice = await SocketPlayer.connect(server.port, 'alice-socket');
    alice.send(const CreateRoom(name: 'Alice', clientId: 'alice-socket'));
    await alice.until(() => alice.room != null);
    final bob = await SocketPlayer.connect(server.port, 'bob-socket-1');
    bob.send(
      JoinRoom(code: alice.room!.code, name: 'Bob', clientId: 'bob-socket-1'),
    );
    await alice.until(() => alice.room!.seats[Seat.north.index].connected);
    await bob.socket.close();
    await alice.until(() => !alice.room!.seats[Seat.north.index].connected);
    await alice.socket.close();
  });
}
