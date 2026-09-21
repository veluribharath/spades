import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spades_app/core/ai/bot_bidder.dart';
import 'package:spades_app/core/ai/bot_card_player.dart';
import 'package:spades_app/core/engine/bidding_rules.dart';
import 'package:spades_app/core/engine/match_state.dart';
import 'package:spades_app/core/models/bid.dart';
import 'package:spades_app/core/models/match_config.dart';
import 'package:spades_app/core/models/seat.dart';

/// Plays one full hand (bidding through the last trick) using only the
/// bot heuristics for every seat.
void _playOutHand(MatchState match) {
  while (match.phase == HandPhase.bidding) {
    final seat = match.nextBidder;
    final bid = chooseBotBid(
      hand: match.hands[seat]!,
      config: match.config,
      isFirstBidOfHand: match.bids.isEmpty,
      teamScore: match.teamScores[seat.team]!,
      opponentScore: match.teamScores[seat.team.opponent]!,
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
  test('Progressive Spades deals 1 card in round 1 and 13 in round 13', () {
    final match = MatchState(
      config: const MatchConfig.progressive(),
      random: Random(3),
      firstDealer: Seat.south,
    );

    expect(match.roundNumber, 1);
    expect(match.handSize, 1);
    for (final hand in match.hands.values) {
      expect(hand, hasLength(1));
    }

    for (var round = 1; round <= 13; round++) {
      expect(match.handSize, round);
      _playOutHand(match);
      expect(match.completedTricks, hasLength(round));

      if (round < 13) {
        match.startNextHand();
        expect(match.roundNumber, round + 1);
        for (final hand in match.hands.values) {
          expect(hand, hasLength(round + 1));
        }
      }
    }

    expect(match.status, MatchStatus.finished);
    expect(match.handHistory, hasLength(13));
  });

  test('a bid above the cards dealt this hand is rejected', () {
    final match = MatchState(
      config: const MatchConfig.progressive(),
      random: Random(9),
      firstDealer: Seat.south,
    );

    expect(match.handSize, 1);
    expect(
      () => match.submitBid(Bid.regular(2)),
      throwsA(isA<IllegalBidException>()),
    );
    expect(() => match.submitBid(Bid.regular(1)), returnsNormally);
  });

  test('progressive bots never propose an over-hand-size bid', () {
    final match = MatchState(
      config: const MatchConfig.progressive(),
      random: Random(11),
      firstDealer: Seat.west,
    );

    while (match.status == MatchStatus.ongoing) {
      while (match.phase == HandPhase.bidding) {
        final seat = match.nextBidder;
        final bid = chooseBotBid(
          hand: match.hands[seat]!,
          config: match.config,
          isFirstBidOfHand: match.bids.isEmpty,
          teamScore: match.teamScores[seat.team]!,
          opponentScore: match.teamScores[seat.team.opponent]!,
        );
        expect(bid.tricks, lessThanOrEqualTo(match.handSize));
        match.submitBid(bid);
      }
      _playOutHand(match);
      if (match.status == MatchStatus.ongoing) match.startNextHand();
    }
  });
}
