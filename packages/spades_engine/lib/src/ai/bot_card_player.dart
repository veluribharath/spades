import '../engine/legal_plays.dart';
import '../engine/trick_resolver.dart';
import '../models/card.dart';
import '../models/seat.dart';
import '../models/suit.dart';
import '../models/trick.dart';

/// A greedy-but-legal card-play heuristic (§Plan milestone 4 "Bot AI v1"):
/// wins as cheaply as possible when it can, ducks/discards low when it
/// can't or when its partner is already winning the trick.
PlayingCard chooseBotCard({
  required Seat seat,
  required List<PlayingCard> hand,
  required Trick trick,
  required bool spadesBroken,
}) {
  final legal = legalPlays(
    hand: hand,
    trick: trick,
    spadesBroken: spadesBroken,
  );
  assert(legal.isNotEmpty, 'No legal plays available');
  if (legal.length == 1) return legal.first;

  if (trick.plays.isEmpty) {
    return _chooseLead(legal);
  }

  final partnerWinning = currentWinner(trick) == seat.partner;
  final leadSuit = trick.leadSuit;
  final followingSuit = legal.every((c) => c.suit == leadSuit);

  final sorted = [...legal]
    ..sort((a, b) => a.rank.value.compareTo(b.rank.value));

  if (partnerWinning) {
    // Duck: dump the lowest card, preferring a non-spade if we have a
    // choice, so we don't waste trump for no reason.
    final nonSpade = sorted.where((c) => !c.isSpade).toList();
    return nonSpade.isNotEmpty ? nonSpade.first : sorted.first;
  }

  if (followingSuit) {
    final spadeAlreadyPlayed = trick.plays.any(
      (e) => e.value.suit == Suit.spades,
    );
    if (spadeAlreadyPlayed) {
      // Can't win by following suit once it's been trumped; dump low.
      return sorted.first;
    }
    final currentHigh = trick.plays
        .map((e) => e.value.rank.value)
        .reduce((a, b) => a > b ? a : b);
    final winners = sorted.where((c) => c.rank.value > currentHigh).toList();
    return winners.isNotEmpty ? winners.first : sorted.first;
  }

  // Void in the suit led: either trump in cheaply or discard low.
  final spadesAvail = sorted.where((c) => c.isSpade).toList();
  if (spadesAvail.isEmpty) return sorted.first;

  final spadeAlreadyPlayed = trick.plays.any(
    (e) => e.value.suit == Suit.spades,
  );
  if (!spadeAlreadyPlayed) {
    return spadesAvail.first; // Cheapest trump wins outright.
  }

  final highestSpadeInTrick = trick.plays
      .where((e) => e.value.suit == Suit.spades)
      .map((e) => e.value.rank.value)
      .reduce((a, b) => a > b ? a : b);
  final overtrumps = spadesAvail
      .where((c) => c.rank.value > highestSpadeInTrick)
      .toList();
  if (overtrumps.isNotEmpty) return overtrumps.first;

  final nonSpade = sorted.where((c) => !c.isSpade).toList();
  return nonSpade.isNotEmpty ? nonSpade.first : sorted.first;
}

PlayingCard _chooseLead(List<PlayingCard> legal) {
  final nonSpade = legal.where((c) => !c.isSpade).toList();
  final pool = nonSpade.isNotEmpty ? nonSpade : legal;

  final bySuit = <Suit, List<PlayingCard>>{};
  for (final card in pool) {
    bySuit.putIfAbsent(card.suit, () => []).add(card);
  }
  final longestSuit =
      bySuit.entries
          .reduce((a, b) => a.value.length >= b.value.length ? a : b)
          .value
        ..sort((a, b) => a.rank.value.compareTo(b.rank.value));
  return longestSuit.first;
}
