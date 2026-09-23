import 'package:flutter_test/flutter_test.dart';
import 'package:spades_app/core/ai/bot_bidder.dart';
import 'package:spades_app/core/models/card.dart';
import 'package:spades_app/core/models/match_config.dart';
import 'package:spades_app/core/models/rank.dart';
import 'package:spades_app/core/models/suit.dart';

/// Regression test: with Nil disabled (Progressive Spades), a weak hand
/// used to always get bumped up to a minimum bid of 1 — there was no way
/// for a bot (or, from the UI, the human) to ever bid a real 0.
void main() {
  group('chooseBotBid', () {
    const weakHand = [PlayingCard(Suit.clubs, Rank.two)];

    test('bids a real 0 on a weak hand when Nil is disabled', () {
      final bid = chooseBotBid(
        hand: weakHand,
        config: const MatchConfig.progressive(),
        isFirstBidOfHand: true,
        teamScore: 0,
        opponentScore: 0,
      );

      expect(bid.tricks, 0);
      expect(bid.isNil, isFalse);
    });

    test('bids Nil instead of a bare 0 when Nil is enabled', () {
      final bid = chooseBotBid(
        hand: weakHand,
        config: const MatchConfig(),
        isFirstBidOfHand: true,
        teamScore: 0,
        opponentScore: 0,
      );

      expect(bid.isNil, isTrue);
    });

    test('never bids above maxBid even with a strong hand', () {
      const strongHand = [
        PlayingCard(Suit.spades, Rank.ace),
        PlayingCard(Suit.spades, Rank.king),
        PlayingCard(Suit.spades, Rank.queen),
        PlayingCard(Suit.hearts, Rank.ace),
      ];
      final bid = chooseBotBid(
        hand: strongHand,
        config: const MatchConfig.progressive(),
        isFirstBidOfHand: false,
        teamScore: 0,
        opponentScore: 0,
        maxBid: 1,
      );

      expect(bid.tricks, lessThanOrEqualTo(1));
    });
  });
}
