import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spades_app/core/ai/bot_bidder.dart';
import 'package:spades_app/core/ai/bot_card_player.dart';
import 'package:spades_app/core/engine/match_state.dart';
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
