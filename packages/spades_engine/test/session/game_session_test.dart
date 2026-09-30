import 'dart:convert';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:spades_engine/multiplayer.dart';
import 'package:spades_engine/spades_engine.dart';
import 'package:test/test.dart';

Map<Seat, SessionPlayer> _players({Set<Seat> humans = const {Seat.south}}) => {
  for (final s in Seat.values)
    s: humans.contains(s)
        ? SessionPlayer.human('H-${s.name}')
        : SessionPlayer.bot('B-${s.name}'),
};

/// Plays every human turn with a bot's choice and confirms every "next
/// hand", advancing the fake clock between steps, until [until] holds.
void _drive(
  FakeAsync async,
  GameSession session, {
  required bool Function() until,
  int maxSteps = 20000,
}) {
  for (var i = 0; i < maxSteps && !until(); i++) {
    final seat = session.toAct;
    if (seat != null && !session.isBotControlled(seat)) {
      final m = session.match;
      if (m.phase == HandPhase.bidding) {
        session.bid(
          seat,
          chooseBotBid(
            hand: m.hands[seat]!,
            config: m.config,
            isFirstBidOfHand: m.bids.isEmpty,
            teamScore: m.teamScores[seat.team]!,
            opponentScore: m.teamScores[seat.team.opponent]!,
            maxBid: m.maxBidFor(seat),
          ),
        );
      } else {
        session.play(seat, m.legalPlaysFor(seat).first);
      }
    } else if (session.awaitingReady.isNotEmpty) {
      session.ready(session.awaitingReady.first);
    } else {
      async.elapse(const Duration(milliseconds: 100));
    }
  }
  expect(until(), isTrue, reason: 'drive did not converge');
}

void main() {
  test('single-player: bots act on their own, the human is waited on', () {
    fakeAsync((async) {
      final session = GameSession(
        players: _players(),
        config: const MatchConfig.progressive(),
        random: Random(1),
        firstDealer: Seat.south,
      );
      // Dealer South → West bids first; bots bid up to the human.
      async.elapse(const Duration(seconds: 5));
      expect(session.match.phase, HandPhase.bidding);
      expect(session.toAct, Seat.south);
      final view = session.viewFor(Seat.south);
      expect(view.isMyBidTurn, isTrue);
      expect(view.maxBid, 1 - session.match.bids[Seat.north]!.teamTricks);
      session.dispose();
    });
  });

  test('the human always bids after a bot partner', () {
    for (final dealer in Seat.values) {
      final session = GameSession(
        players: _players(humans: {Seat.south, Seat.east}),
        random: Random(dealer.index),
        firstDealer: dealer,
      );
      final order = session.match.biddingOrder;
      expect(order.indexOf(Seat.north), lessThan(order.indexOf(Seat.south)));
      expect(order.indexOf(Seat.west), lessThan(order.indexOf(Seat.east)));
      session.dispose();
    }
  });

  test('a view never exposes another seat\'s cards', () {
    fakeAsync((async) {
      final session = GameSession(
        players: _players(),
        random: Random(3),
        firstDealer: Seat.east,
      );
      async.elapse(const Duration(seconds: 5));
      final json = jsonEncode(session.viewFor(Seat.south).toJson());
      final decoded = TableView.fromJson(jsonDecode(json));
      expect(decoded.hand, session.match.hands[Seat.south]);
      final others = [
        for (final s in [Seat.west, Seat.north, Seat.east])
          ...session.match.hands[s]!,
      ];
      final played = decoded.trickPlays.map((p) => p.value).toSet();
      for (final card in others) {
        if (played.contains(card)) continue;
        expect(
          json.contains('"${encodeCard(card)}"'),
          isFalse,
          reason: '$card leaked',
        );
      }
      expect(decoded.seats.map((s) => s.cardCount), everyElement(13));
      session.dispose();
    });
  });

  test('out-of-turn, illegal and over-cap actions are rejected', () {
    fakeAsync((async) {
      final session = GameSession(
        players: _players(humans: Seat.values.toSet()),
        config: const MatchConfig.progressive(),
        random: Random(4),
        firstDealer: Seat.south,
      );
      // West bids first (dealer's left).
      expect(
        () => session.bid(Seat.south, Bid.regular(0)),
        throwsA(isA<SessionException>()),
      );
      expect(
        () => session.bid(Seat.west, Bid.regular(2)),
        throwsA(isA<SessionException>()),
        reason: 'only one card dealt in round 1',
      );
      session.bid(Seat.west, Bid.regular(1));
      session.bid(Seat.north, Bid.regular(1));
      expect(
        () => session.bid(Seat.east, Bid.regular(1)),
        throwsA(isA<SessionException>()),
        reason: 'West already claimed the only trick for that team',
      );
      session.bid(Seat.east, Bid.regular(0));
      session.bid(Seat.south, Bid.regular(0));
      expect(session.match.phase, HandPhase.playing);
      final leader = session.toAct!;
      final notLeader = leader.next;
      expect(
        () => session.play(notLeader, session.match.hands[notLeader]!.first),
        throwsA(isA<SessionException>()),
      );
      expect(
        () => session.play(leader, session.match.hands[notLeader]!.first),
        throwsA(isA<SessionException>()),
        reason: 'not a card in their hand',
      );
      session.dispose();
    });
  });

  test('a completed trick is held before anyone can act', () {
    fakeAsync((async) {
      final session = GameSession(
        players: _players(),
        random: Random(5),
        firstDealer: Seat.north,
      );
      _drive(
        async,
        session,
        until: () => session.match.completedTricks.isNotEmpty,
      );
      final view = session.viewFor(Seat.south);
      expect(view.trickHeld, isTrue);
      expect(view.trickPlays, hasLength(4));
      expect(view.toAct, isNull);
      expect(view.trickWinner, resolveTrick(session.match.completedTricks[0]));
      async.elapse(session.timing.trickHold);
      expect(session.viewFor(Seat.south).trickHeld, isFalse);
      session.dispose();
    });
  });

  test('the last trick stays on screen before the hand summary', () {
    fakeAsync((async) {
      final session = GameSession(
        players: _players(),
        config: const MatchConfig.progressive(),
        random: Random(6),
        firstDealer: Seat.west,
      );
      _drive(
        async,
        session,
        until: () => session.match.phase == HandPhase.complete,
      );
      expect(session.viewFor(Seat.south).phase, HandPhase.playing);
      expect(session.awaitingReady, isEmpty);
      async.elapse(session.timing.trickHold);
      final view = session.viewFor(Seat.south);
      expect(view.phase, HandPhase.complete);
      expect(view.awaitingReady, {Seat.south});
      expect(view.history, hasLength(1));
      session.dispose();
    });
  });

  test('next hand waits for every connected human', () {
    fakeAsync((async) {
      final session = GameSession(
        players: _players(humans: {Seat.south, Seat.west}),
        config: const MatchConfig.progressive(),
        random: Random(7),
      );
      _drive(
        async,
        session,
        until: () =>
            session.match.phase == HandPhase.complete &&
            session.awaitingReady.isNotEmpty,
      );
      expect(session.awaitingReady, {Seat.south, Seat.west});
      session.ready(Seat.south);
      expect(session.match.roundNumber, 1);
      expect(session.viewFor(Seat.south).iAmReady, isTrue);
      // West drops: they no longer hold up the table.
      session.setConnected(Seat.west, false);
      expect(session.match.roundNumber, 2);
      expect(session.viewFor(Seat.south).info(Seat.west).connected, isFalse);
      session.dispose();
    });
  });

  test('autopilot plays for a dropped human and hands control back', () {
    fakeAsync((async) {
      final session = GameSession(
        players: _players(humans: {Seat.south, Seat.north}),
        random: Random(8),
        firstDealer: Seat.east,
      );
      // Dealer East → South bids first; nobody else can move.
      async.elapse(const Duration(seconds: 5));
      expect(session.toAct, Seat.south);
      session.setConnected(Seat.south, false);
      session.setAutopilot(Seat.south, true);
      expect(
        () => session.bid(Seat.south, Bid.regular(1)),
        throwsA(isA<SessionException>()),
      );
      async.elapse(const Duration(seconds: 2));
      expect(session.match.bids.containsKey(Seat.south), isTrue);
      // West (a bot) bid right after; North is a human, so it waits.
      expect(session.match.bids.containsKey(Seat.west), isTrue);
      expect(session.toAct, Seat.north);
      session.setAutopilot(Seat.south, false);
      session.setConnected(Seat.south, true);
      expect(session.isBotControlled(Seat.south), isFalse);
      session.dispose();
    });
  });

  test('a full progressive match runs to the end', () {
    fakeAsync((async) {
      final session = GameSession(
        players: _players(humans: {Seat.south, Seat.east}),
        config: const MatchConfig.progressive(),
        random: Random(9),
      );
      var changes = 0;
      session.onChanged = () => changes++;
      _drive(
        async,
        session,
        until: () => session.match.status == MatchStatus.finished,
      );
      async.elapse(session.timing.trickHold);
      final view = session.viewFor(Seat.east);
      expect(view.matchOver, isTrue);
      expect(view.history, hasLength(13));
      expect(view.winner, isNotNull);
      expect(view.awaitingReady, isEmpty);
      expect(changes, greaterThan(100));
      expect(() => session.ready(Seat.south), throwsA(isA<SessionException>()));
      session.dispose();
    });
  });

  test('views survive a JSON round trip unchanged', () {
    fakeAsync((async) {
      final session = GameSession(
        players: _players(),
        random: Random(10),
        firstDealer: Seat.south,
      );
      _drive(
        async,
        session,
        until: () => session.match.completedTricks.length >= 2,
      );
      for (final seat in Seat.values) {
        final original = session.viewFor(seat).toJson();
        final again = TableView.fromJson(
          jsonDecode(jsonEncode(original)),
        ).toJson();
        expect(jsonEncode(again), jsonEncode(original));
      }
      session.dispose();
    });
  });

  test('disposing stops all timers', () {
    fakeAsync((async) {
      final session = GameSession(players: _players(), random: Random(11));
      session.dispose();
      async.elapse(const Duration(minutes: 1));
      expect(async.pendingTimers, isEmpty);
    });
  });

  group('codec', () {
    test('cards and bids round-trip', () {
      for (final card in buildStandardDeck()) {
        expect(decodeCard(encodeCard(card)), card);
      }
      for (final bid in [
        Bid.nil(),
        Bid.blindNil(),
        Bid.regular(0),
        Bid.regular(13),
      ]) {
        expect(encodeBid(decodeBid(encodeBid(bid))), encodeBid(bid));
      }
    });

    test('garbage is rejected with DecodeException', () {
      for (final bad in [null, 3, '', 'ZZ', '1S', '11H', 'AX', 'A']) {
        expect(() => decodeCard(bad), throwsA(isA<DecodeException>()));
      }
      for (final bad in [null, 3, '14', '-1', 'x']) {
        expect(() => decodeBid(bad), throwsA(isA<DecodeException>()));
      }
      expect(
        () => TableView.fromJson({'seat': 'south'}),
        throwsA(isA<DecodeException>()),
      );
    });
  });
}
