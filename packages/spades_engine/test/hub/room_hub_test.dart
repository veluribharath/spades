import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:spades_engine/multiplayer.dart';
import 'package:spades_engine/spades_engine.dart';
import 'package:test/test.dart';

/// An in-memory client: records what the hub sends and can talk back.
class FakeClient implements PeerConnection {
  FakeClient(RoomHub hub, this.clientId, {this.name = 'Player'}) {
    peer = hub.connect(this);
  }

  late final HubPeer peer;
  final String clientId;
  final String name;
  final List<ServerMessage> received = [];
  bool isClosed = false;

  @override
  void send(String message) => received.add(ServerMessage.decode(message));

  @override
  void close() => isClosed = true;

  void say(ClientMessage m) => peer.receive(m.encode());

  void create() => say(CreateRoom(name: name, clientId: clientId));

  void join(String code) =>
      say(JoinRoom(code: code, name: name, clientId: clientId));

  RoomSnapshot get room => received.whereType<RoomSnapshot>().last;
  TableView get view => room.view!;
  ErrorMessage? get lastError => received.lastOrNull is ErrorMessage
      ? received.last as ErrorMessage
      : null;
  List<ErrorMessage> get errors => received.whereType<ErrorMessage>().toList();

  /// Takes this client's turn (if it is one) the way a bot would.
  bool act() {
    final v = view;
    if (v.isMyBidTurn) {
      final hand = v.hand;
      say(
        PlaceBid(
          chooseBotBid(
            hand: hand,
            config: v.config,
            isFirstBidOfHand: v.isFirstBid,
            teamScore: v.teamScores[v.seat.team]!,
            opponentScore: v.teamScores[v.seat.team.opponent]!,
            maxBid: v.maxBid,
          ),
        ),
      );
      return true;
    }
    if (v.isMyPlayTurn) {
      say(PlayCard(v.legalCards.first));
      return true;
    }
    if (v.phase == HandPhase.complete && !v.matchOver && !v.iAmReady) {
      say(const ReadyForNextHand());
      return true;
    }
    return false;
  }
}

RoomHub _hub() => RoomHub(
  random: Random(42),
  timing: const SessionTiming.instant(),
  reconnectGrace: const Duration(seconds: 20),
  idleRoomTimeout: const Duration(minutes: 10),
);

void main() {
  test('create → join → lobby seats → start', () {
    fakeAsync((async) {
      final hub = _hub();
      final alice = FakeClient(hub, 'alice-0001', name: 'Alice')..create();
      final code = alice.room.code;
      expect(code, matches(RegExp(r'^[A-Z]{4}$')));
      expect(alice.room.youAreHost, isTrue);
      expect(alice.room.yourSeat, Seat.south);

      final bob = FakeClient(hub, 'bob-00001', name: 'Bob')
        ..join(code.toLowerCase());
      expect(bob.room.yourSeat, Seat.north, reason: 'partner seat first');
      expect(bob.room.youAreHost, isFalse);
      expect(alice.room.seats[Seat.north.index].name, 'Bob');

      bob.say(const Sit(Seat.east));
      expect(alice.room.seats[Seat.east.index].name, 'Bob');
      expect(alice.room.seats[Seat.north.index].isEmpty, isTrue);

      bob.say(const Sit(Seat.south));
      expect(bob.lastError?.message, 'That seat is taken.');

      bob.say(const StartGame());
      expect(bob.lastError?.message, contains('Only the host'));
      bob.say(const SetBot(Seat.west, bot: true));
      expect(bob.lastError?.message, contains('Only the host'));

      alice.say(const SetBot(Seat.west, bot: true));
      expect(bob.room.seats[Seat.west.index].isBot, isTrue);

      alice.say(const StartGame());
      expect(alice.room.started, isTrue);
      expect(bob.view.seat, Seat.east);
      expect(
        bob.view.info(Seat.north).isBot,
        isTrue,
        reason: 'filled at start',
      );
      expect(bob.view.info(Seat.south).name, 'Alice');
      expect(bob.view.hand, hasLength(1));

      final carol = FakeClient(hub, 'carol-0001')..join(code);
      expect(carol.lastError?.fatal, isTrue);
      expect(carol.lastError?.message, contains('already started'));
      hub.dispose();
    });
  });

  test('two humans play a whole progressive match through the hub', () {
    fakeAsync((async) {
      final hub = _hub();
      final alice = FakeClient(hub, 'alice-0001', name: 'Alice')..create();
      final bob = FakeClient(hub, 'bob-00001', name: 'Bob')
        ..join(alice.room.code);
      bob.say(const Sit(Seat.west));
      alice.say(const StartGame());

      for (var i = 0; i < 20000 && !alice.view.matchOver; i++) {
        if (!alice.act() && !bob.act()) {
          async.elapse(const Duration(milliseconds: 50));
        }
      }
      async.elapse(const Duration(seconds: 1));
      expect(alice.view.matchOver, isTrue);
      expect(alice.view.history, hasLength(13));
      expect(bob.view.teamScores, alice.view.teamScores);
      expect(alice.errors, isEmpty);
      expect(bob.errors, isEmpty);
      hub.dispose();
    });
  });

  test('bad input gets an error, not a crash', () {
    fakeAsync((async) {
      final hub = _hub();
      final x = FakeClient(hub, 'xxxxxxxx-1');
      x.peer.receive('not json');
      expect(x.lastError?.message, contains("Couldn't understand"));
      x.peer.receive('{"type":"bid","bid":"99"}');
      expect(x.lastError, isNotNull);
      x.say(PlaceBid(Bid.regular(1)));
      expect(x.lastError?.message, 'Join a room first.');
      x.peer.receive('{"type":"create","v":1,"name":"a","clientId":"!!"}');
      expect(x.lastError?.message, 'Invalid client id.');
      x.peer.receive(
        '{"type":"create","v":99,"name":"a","clientId":"xxxxxxxx-1"}',
      );
      expect(x.lastError?.message, contains('different version'));
      x.peer.receive('x' * 5000);
      expect(x.lastError?.message, contains('too large'));
      x.join('ZZZZ');
      expect(x.lastError?.fatal, isTrue);
      expect(hub.roomCount, 0);
      hub.dispose();
    });
  });

  test('names are cleaned up', () {
    fakeAsync((async) {
      final hub = _hub();
      final a = FakeClient(
        hub,
        'aaaaaaaa-1',
        name: '  \u0007 Very   long name that goes on and on ',
      )..create();
      final seat = a.room.seats[Seat.south.index];
      expect(seat.name, 'Very long name that');
      final b = FakeClient(hub, 'bbbbbbbb-1', name: '   ')..join(a.room.code);
      expect(b.room.seats[Seat.north.index].name, 'Player');
      hub.dispose();
    });
  });

  test('out-of-turn actions are refused and the client is resynced', () {
    fakeAsync((async) {
      final hub = _hub();
      final alice = FakeClient(hub, 'alice-0001')..create();
      final bob = FakeClient(hub, 'bob-00001')..join(alice.room.code);
      alice.say(const StartGame());
      async.elapse(const Duration(seconds: 1));
      final waiting = alice.view.isMyBidTurn ? bob : alice;
      final before = waiting.received.length;
      waiting.say(PlaceBid(Bid.regular(0)));
      expect(waiting.received[before], isA<ErrorMessage>());
      expect(waiting.received.last, isA<RoomSnapshot>());
      hub.dispose();
    });
  });

  test(
    'a dropped player keeps their seat, then a bot covers, then they resume',
    () {
      fakeAsync((async) {
        final hub = _hub();
        final alice = FakeClient(hub, 'alice-0001', name: 'Alice')..create();
        final code = alice.room.code;
        final bob = FakeClient(hub, 'bob-00001', name: 'Bob')..join(code);
        alice.say(const StartGame());
        async.elapse(const Duration(milliseconds: 10));

        bob.peer.closed();
        expect(alice.view.info(Seat.north).connected, isFalse);
        expect(alice.view.info(Seat.north).autopilot, isFalse);

        async.elapse(const Duration(seconds: 21));
        expect(alice.view.info(Seat.north).autopilot, isTrue);

        // Everyone keeps playing; North's turns are taken by the bot.
        for (var i = 0; i < 200 && alice.view.roundNumber < 3; i++) {
          if (!alice.act()) async.elapse(const Duration(milliseconds: 50));
        }
        expect(alice.view.roundNumber, 3);

        final bobAgain = FakeClient(hub, 'bob-00001', name: 'Bob')..join(code);
        expect(bobAgain.room.yourSeat, Seat.north);
        expect(
          bobAgain.view.hand.length,
          bobAgain.view.info(Seat.north).cardCount,
        );
        expect(alice.view.info(Seat.north).connected, isTrue);
        expect(alice.view.info(Seat.north).autopilot, isFalse);
        hub.dispose();
      });
    },
  );

  test('joining again from a second connection retires the first', () {
    fakeAsync((async) {
      final hub = _hub();
      final a1 = FakeClient(hub, 'alice-0001')..create();
      final a2 = FakeClient(hub, 'alice-0001')..join(a1.room.code);
      expect(a1.isClosed, isTrue);
      expect(a1.lastError?.fatal, isTrue);
      expect(a2.room.yourSeat, Seat.south);
      expect(a2.room.youAreHost, isTrue);
      // The retired connection's late close doesn't disconnect Alice.
      a1.peer.closed();
      expect(a2.room.seats[Seat.south.index].connected, isTrue);
      hub.dispose();
    });
  });

  test(
    'lobby: leaving frees the seat and passes host on; empty rooms close',
    () {
      fakeAsync((async) {
        final hub = _hub();
        final alice = FakeClient(hub, 'alice-0001', name: 'Alice')..create();
        final code = alice.room.code;
        final bob = FakeClient(hub, 'bob-00001', name: 'Bob')..join(code);
        alice.say(const LeaveRoom());
        expect(bob.room.youAreHost, isTrue);
        expect(bob.room.seats[Seat.south.index].isEmpty, isTrue);

        // A lobby drop frees the seat after the grace period.
        bob.peer.closed();
        expect(hub.hasRoom(code), isTrue);
        async.elapse(const Duration(seconds: 21));
        expect(hub.hasRoom(code), isFalse);
        hub.dispose();
      });
    },
  );

  test('a started room with nobody connected is cleaned up', () {
    fakeAsync((async) {
      final hub = _hub();
      final alice = FakeClient(hub, 'alice-0001')..create();
      final code = alice.room.code;
      alice.say(const StartGame());
      alice.peer.closed();
      async.elapse(const Duration(minutes: 9));
      expect(hub.hasRoom(code), isTrue);
      async.elapse(const Duration(minutes: 2));
      expect(hub.hasRoom(code), isFalse);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('a fifth player is turned away; a bot seat is given up to a human', () {
    fakeAsync((async) {
      final hub = _hub();
      final a = FakeClient(hub, 'aaaaaaaa-1')..create();
      final code = a.room.code;
      a.say(const SetBot(Seat.north, bot: true));
      final b = FakeClient(hub, 'bbbbbbbb-1')..join(code);
      expect(b.room.yourSeat, Seat.west, reason: 'empty seats before bots');
      final c = FakeClient(hub, 'cccccccc-1')..join(code);
      expect(c.room.yourSeat, Seat.east);
      final d = FakeClient(hub, 'dddddddd-1')..join(code);
      expect(d.room.yourSeat, Seat.north, reason: 'replaced the bot');
      final e = FakeClient(hub, 'eeeeeeee-1')..join(code);
      expect(e.lastError?.message, 'That room is full.');
      hub.dispose();
    });
  });

  test('leaving mid-game hands the seat to a bot immediately', () {
    fakeAsync((async) {
      final hub = _hub();
      final alice = FakeClient(hub, 'alice-0001')..create();
      final bob = FakeClient(hub, 'bob-00001')..join(alice.room.code);
      alice.say(const StartGame());
      bob.say(const LeaveRoom());
      expect(alice.view.info(Seat.north).autopilot, isTrue);
      final n = bob.received.length;
      async.elapse(const Duration(seconds: 1));
      expect(bob.received.length, n, reason: 'no more updates after leaving');
      hub.dispose();
    });
  });

  test('closing the hub tells connected players, fatally', () {
    fakeAsync((async) {
      final hub = _hub();
      final alice = FakeClient(hub, 'alice-0001')..create();
      final bob = FakeClient(hub, 'bob-00001')..join(alice.room.code);
      hub.dispose(reason: 'The host closed the room.');
      for (final c in [alice, bob]) {
        expect(c.lastError?.message, 'The host closed the room.');
        expect(c.lastError?.fatal, isTrue);
        expect(c.isClosed, isTrue);
      }
      expect(hub.roomCount, 0);
    });
  });

  test('a reconnect sends each player exactly one snapshot', () {
    fakeAsync((async) {
      final hub = _hub();
      final alice = FakeClient(hub, 'alice-0001')..create();
      final code = alice.room.code;
      final bob = FakeClient(hub, 'bob-00001')..join(code);
      alice.say(const StartGame());
      async.elapse(const Duration(milliseconds: 10));
      bob.peer.closed();
      async.elapse(const Duration(seconds: 25));
      final before = alice.received.length;
      final bobAgain = FakeClient(hub, 'bob-00001')..join(code);
      expect(alice.received.length - before, 1);
      expect(bobAgain.received, hasLength(1));
      hub.dispose();
    });
  });

  test('long names are cut without splitting an emoji', () {
    fakeAsync((async) {
      final hub = _hub();
      final a = FakeClient(hub, 'aaaaaaaa-1', name: '${'a' * 19}😀😀')
        ..create();
      final name = a.room.seats[Seat.south.index].name!;
      expect(name, '${'a' * 19}😀');
      hub.dispose();
    });
  });
}
