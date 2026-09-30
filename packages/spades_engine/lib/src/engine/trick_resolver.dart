import '../models/seat.dart';
import '../models/suit.dart';
import '../models/trick.dart';

/// The seat currently "winning" [trick], whether or not it's complete yet:
/// highest spade played so far, or if none, the highest card of the suit
/// led so far. Used both to resolve finished tricks and by the bot AI to
/// reason about a trick in progress.
Seat currentWinner(Trick trick) {
  assert(trick.plays.isNotEmpty, 'Trick has no plays yet');

  final spadesPlayed = trick.plays
      .where((e) => e.value.suit == Suit.spades)
      .toList();

  final contenders = spadesPlayed.isNotEmpty
      ? spadesPlayed
      : trick.plays.where((e) => e.value.suit == trick.leadSuit).toList();

  return contenders
      .reduce((a, b) => a.value.rank.value >= b.value.rank.value ? a : b)
      .key;
}

/// Determines the winning seat of a completed [trick], per
/// docs/RULES.md §4: highest spade played wins; if no spade was played,
/// the highest card of the suit led wins.
Seat resolveTrick(Trick trick) {
  assert(trick.isComplete, 'Cannot resolve an incomplete trick');
  return currentWinner(trick);
}
