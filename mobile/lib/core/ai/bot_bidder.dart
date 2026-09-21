import '../models/bid.dart';
import '../models/card.dart';
import '../models/match_config.dart';
import '../models/suit.dart';

/// A simple rule-of-thumb bid estimator (§Plan milestone 4 "Bot AI v1"):
/// counts high spades, spade length, and protected off-suit honors.
/// Not game-theoretically optimal, but plausible and legal.
Bid chooseBotBid({
  required List<PlayingCard> hand,
  required MatchConfig config,
  required bool isFirstBidOfHand,
  required int teamScore,
  required int opponentScore,
}) {
  final spades = hand.where((c) => c.suit == Suit.spades).toList();

  double estimate = 0;
  for (final card in spades) {
    if (card.rank.value >= 12) {
      estimate += 1; // Q, K, A of spades are near-sure tricks.
    } else if (card.rank.value >= 10) {
      estimate += 0.5; // 10, J of spades often win late.
    }
  }
  if (spades.length > 4) estimate += (spades.length - 4) * 0.7;
  if (spades.isEmpty) estimate -= 0.5;

  for (final suit in Suit.values) {
    if (suit == Suit.spades) continue;
    final cards = hand.where((c) => c.suit == suit).toList()
      ..sort((a, b) => b.rank.value.compareTo(a.rank.value));
    if (cards.isEmpty) continue;
    if (cards.first.rank.value == 14) estimate += 1; // Ace.
    if (cards.length >= 2 && cards[1].rank.value == 13) {
      estimate += 0.75; // Protected King.
    }
    if (cards.length >= 3 &&
        cards.length > 1 &&
        cards[0].rank.value != 14 &&
        cards[0].rank.value == 13) {
      estimate += 0.5; // Unprotected-by-ace but decently guarded King.
    }
  }

  final rounded = estimate.round().clamp(0, 13);

  if (rounded == 0 &&
      config.nilEnabled &&
      spades.length <= 2 &&
      !spades.any((c) => c.rank.value >= 12)) {
    final behind = opponentScore - teamScore;
    if (config.blindNilEnabled && isFirstBidOfHand && behind >= 100) {
      return Bid.blindNil();
    }
    return Bid.nil();
  }

  return Bid.regular(rounded == 0 ? 1 : rounded);
}
