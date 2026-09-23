import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spades_app/core/ai/bot_bidder.dart';
import 'package:spades_app/core/ai/bot_card_player.dart';
import 'package:spades_app/core/engine/match_state.dart';
import 'package:spades_app/core/models/bid.dart';
import 'package:spades_app/core/models/match_config.dart';
import 'package:spades_app/core/models/seat.dart';

/// Drives a [MatchState] to completion using only the bot heuristics,
/// exercising the full bidding -> playing -> scoring -> next-hand loop.
void _playOutHand(MatchState match) {
  while (match.phase == HandPhase.bidding) {
    final seat = match.nextBidder;
    final bid = chooseBotBid(
      hand: match.hands[seat]!,
      config: match.config,
      isFirstBidOfHand: match.bids.isEmpty,
      teamScore: match.teamScores[seat.team]!,
      opponentScore: match.teamScores[seat.team.opponent]!,
      maxBid: match.maxBidFor(seat),
    );
    match.submitBid(bid);
  }

  while (match.phase == HandPhase.playing) {
    final trick = match.currentTrick!;
    final seat = trick.nextToPlay;
    final card = chooseBotCard(
      seat: seat,
      hand: match.hands[seat]!,
      trick: trick,
      spadesBroken: match.spadesBroken,
    );
    match.playCard(seat, card);
  }
}

void main() {
  biddingOrderTests();

  test('a full hand played by bots reaches HandPhase.complete cleanly', () {
    final match = MatchState(random: Random(123), firstDealer: Seat.south);
    _playOutHand(match);

    expect(match.phase, HandPhase.complete);
    expect(match.completedTricks, hasLength(13));
    for (final hand in match.hands.values) {
      expect(hand, isEmpty);
    }

    final totalTricks = match.tricksWonThisHand.values.reduce((a, b) => a + b);
    expect(totalTricks, 13);
    expect(match.handHistory, hasLength(1));
  });

  test('dealer rotates clockwise between hands', () {
    final match = MatchState(random: Random(1), firstDealer: Seat.south);
    _playOutHand(match);
    match.startNextHand();
    expect(match.dealer, Seat.west);
  });

  test('playing out of turn throws', () {
    final match = MatchState(random: Random(1), firstDealer: Seat.south);
    while (match.phase == HandPhase.bidding) {
      match.submitBid(
        chooseBotBid(
          hand: match.hands[match.nextBidder]!,
          config: match.config,
          isFirstBidOfHand: match.bids.isEmpty,
          teamScore: 0,
          opponentScore: 0,
          maxBid: match.maxBidFor(match.nextBidder),
        ),
      );
    }
    final trick = match.currentTrick!;
    final outOfTurnSeat = trick.nextToPlay.next;
    final card = match.hands[outOfTurnSeat]!.first;
    expect(() => match.playCard(outOfTurnSeat, card), throwsStateError);
  });

  test('a full match played by bots eventually finishes', () {
    final match = MatchState(
      random: Random(99),
      firstDealer: Seat.south,
      config: const MatchConfig(targetScore: 150),
    );

    var hands = 0;
    while (match.status == MatchStatus.ongoing && hands < 200) {
      _playOutHand(match);
      hands++;
      if (match.status == MatchStatus.ongoing) {
        match.startNextHand();
      }
    }

    expect(match.status, isNot(MatchStatus.ongoing));
    expect(hands, lessThan(200), reason: 'match should terminate');
  });
}

void _bidRemaining(MatchState match, List<Seat> seen) {
  while (match.phase == HandPhase.bidding) {
    seen.add(match.nextBidder);
    match.submitBid(Bid.regular(0));
  }
}

void biddingOrderTests() {
  group('bidding order', () {
    test('starts left of the dealer and goes clockwise', () {
      final match = MatchState(
        config: const MatchConfig(nilEnabled: false),
        random: Random(1),
        firstDealer: Seat.west,
      );
      final seen = <Seat>[];
      _bidRemaining(match, seen);
      expect(seen, [Seat.north, Seat.east, Seat.south, Seat.west]);
    });

    test('first bidder rotates with the dealer each hand', () {
      final match = MatchState(
        config: const MatchConfig(nilEnabled: false),
        random: Random(1),
        firstDealer: Seat.south,
      );
      final firstBidders = <Seat>[];
      for (var hand = 0; hand < 4; hand++) {
        firstBidders.add(match.nextBidder);
        _playOutHand(match);
        match.startNextHand();
      }
      expect(firstBidders, [Seat.west, Seat.north, Seat.east, Seat.south]);
    });

    test('final-say seat always bids after its partner', () {
      for (final dealer in Seat.values) {
        final match = MatchState(
          config: const MatchConfig(nilEnabled: false),
          random: Random(1),
          firstDealer: dealer,
          finalSaySeat: Seat.south,
        );
        final seen = <Seat>[];
        _bidRemaining(match, seen);
        expect(seen.toSet(), Seat.values.toSet(), reason: 'dealer $dealer');
        expect(
          seen.indexOf(Seat.north),
          lessThan(seen.indexOf(Seat.south)),
          reason: 'dealer $dealer: $seen',
        );
        expect(seen.first, isNot(Seat.south), reason: 'dealer $dealer');
      }
    });
  });
}
