import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spades_app/state/remote_table_client.dart';
import 'package:spades_app/state/table_client.dart';
import 'package:spades_engine/multiplayer.dart';
import 'package:spades_engine/spades_engine.dart';

import '../support/in_memory_hub.dart';

final _server = Uri.parse('ws://test:8080/');

Future<void> _until(RemoteTableClient client, bool Function() condition) async {
  if (condition()) return;
  final done = Completer<void>();
  void check() {
    if (!done.isCompleted && condition()) done.complete();
  }

  client.addListener(check);
  try {
    await done.future.timeout(const Duration(seconds: 20));
  } finally {
    client.removeListener(check);
  }
}

/// Takes this player's turn whenever the view asks for one.
void _autoplay(RemoteTableClient client) {
  client.addListener(() {
    final v = client.view;
    if (v == null || client.awaitingServer) return;
    if (v.isMyBidTurn) {
      client.bid(
        chooseBotBid(
          hand: v.hand,
          config: v.config,
          isFirstBidOfHand: v.isFirstBid,
          teamScore: 0,
          opponentScore: 0,
          maxBid: v.maxBid,
        ),
      );
    } else if (v.isMyPlayTurn) {
      client.play(v.legalCards.first);
    } else if (v.phase == HandPhase.complete && !v.matchOver && !v.iAmReady) {
      client.nextHand();
    }
  });
}

void main() {
  late RoomHub hub;
  late InMemoryHub net;

  setUp(() {
    hub = RoomHub(random: Random(3), timing: const SessionTiming.instant());
    net = InMemoryHub(hub);
  });

  tearDown(() => hub.dispose());

  RemoteTableClient client(String id, {String? code, String name = 'P'}) =>
      RemoteTableClient(
        server: _server,
        name: name,
        clientId: id,
        roomCode: code,
        connect: net.connect,
        maxBackoff: const Duration(milliseconds: 50),
      );

  test('host and a friend play a full match', () async {
    final alice = client('alice-client', name: 'Alice');
    await _until(alice, () => alice.room != null);
    expect(alice.status, ConnectionStatus.connected);
    expect(alice.room!.youAreHost, isTrue);

    final bob = client('bob-client-1', code: alice.code, name: 'Bob');
    await _until(bob, () => bob.room != null);
    expect(bob.room!.yourSeat, Seat.north);

    _autoplay(alice);
    _autoplay(bob);
    alice.start();
    await _until(alice, () => alice.view?.matchOver ?? false);
    await _until(bob, () => bob.view?.matchOver ?? false);
    expect(alice.view!.history, hasLength(13));
    expect(alice.error, isNull);
    expect(bob.error, isNull);
    alice.dispose();
    bob.dispose();
  });

  test('a dropped connection reconnects and resumes the same seat', () async {
    final alice = client('alice-client', name: 'Alice');
    await _until(alice, () => alice.room != null);
    final bob = client('bob-client-1', code: alice.code, name: 'Bob');
    await _until(bob, () => bob.room != null);
    alice.start();
    await _until(bob, () => bob.view != null);
    final handBefore = bob.view!.hand;

    net.dropAll();
    await _until(bob, () => bob.status == ConnectionStatus.reconnecting);
    await _until(bob, () => bob.status == ConnectionStatus.connected);
    await _until(alice, () => alice.status == ConnectionStatus.connected);
    expect(bob.room!.yourSeat, Seat.north);
    expect(bob.view!.hand, handBefore);
    expect(hub.roomCount, 1);
    alice.dispose();
    bob.dispose();
  });

  test('a double tap sends only one action', () async {
    final alice = client('alice-client');
    await _until(alice, () => alice.room != null);
    alice.start();
    await _until(alice, () => alice.view?.isMyBidTurn ?? false);
    alice.bid(Bid.regular(0));
    expect(alice.awaitingServer, isTrue);
    alice.bid(Bid.regular(0));
    await _until(alice, () => !alice.awaitingServer);
    expect(
      alice.error,
      isNull,
      reason: 'the second tap never reached the server',
    );
    alice.dispose();
  });

  test('a wrong room code is fatal and stops retrying', () async {
    final bob = client('bob-client-1', code: 'ZZZZ');
    await _until(bob, () => bob.fatalError != null);
    expect(bob.fatalError, contains('ZZZZ'));
    expect(bob.status, ConnectionStatus.closed);
    bob.dispose();
  });

  test('an unreachable server gives up after a few tries', () async {
    net.refuse = true;
    final bob = client('bob-client-1', code: 'ABCD');
    await _until(bob, () => bob.fatalError != null);
    expect(bob.fatalError, contains("Couldn't reach"));
    bob.dispose();
  });

  test('leaving in the lobby frees the seat for others', () async {
    final alice = client('alice-client', name: 'Alice');
    await _until(alice, () => alice.room != null);
    final bob = client('bob-client-1', code: alice.code, name: 'Bob');
    await _until(alice, () => !alice.room!.seats[Seat.north.index].isEmpty);
    bob.leave();
    expect(bob.status, ConnectionStatus.closed);
    await _until(alice, () => alice.room!.seats[Seat.north.index].isEmpty);
    alice.dispose();
    bob.dispose();
  });

  test(
    'when the host closes the room, everyone is told and stops retrying',
    () async {
      final alice = client('alice-client');
      await _until(alice, () => alice.room != null);
      final bob = client('bob-client-1', code: alice.code);
      await _until(bob, () => bob.room != null);
      hub.dispose(reason: 'The host closed the room.');
      await _until(bob, () => bob.fatalError != null);
      expect(bob.fatalError, 'The host closed the room.');
      expect(bob.status, ConnectionStatus.closed);
      final connections = net.connectionCount;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(net.connectionCount, connections, reason: 'no reconnect attempts');
      alice.dispose();
      bob.dispose();
    },
  );

  test('an established game gives up after a long outage', () async {
    final alice = RemoteTableClient(
      server: _server,
      name: 'A',
      clientId: 'alice-client',
      connect: net.connect,
      maxBackoff: const Duration(milliseconds: 20),
      giveUpAfter: const Duration(milliseconds: 300),
    );
    await _until(alice, () => alice.room != null);
    net.refuse = true;
    net.dropAll();
    await _until(alice, () => alice.status == ConnectionStatus.reconnecting);
    await _until(alice, () => alice.fatalError != null);
    expect(alice.fatalError, contains('Lost the connection'));
    alice.dispose();
  });
}
