import 'dart:math';

import '../models/card.dart';
import '../models/seat.dart';

/// Shuffles a standard deck and deals [cardsPerPlayer] cards to each of
/// the 4 seats (13 by default, per docs/RULES.md §2). A smaller
/// [cardsPerPlayer] — used by the Progressive Spades variant (§7) — deals
/// from the top of the shuffled deck and leaves the rest unused.
/// [random] is injectable for deterministic tests.
Map<Seat, List<PlayingCard>> dealHand({
  int cardsPerPlayer = 13,
  Random? random,
}) {
  assert(
    cardsPerPlayer >= 1 && cardsPerPlayer <= 13,
    'cardsPerPlayer must be 1-13',
  );
  final deck = buildStandardDeck()..shuffle(random ?? Random());
  final hands = {for (final seat in Seat.values) seat: <PlayingCard>[]};

  final cardsToDeal = cardsPerPlayer * Seat.values.length;
  for (var i = 0; i < cardsToDeal; i++) {
    final seat = Seat.values[i % Seat.values.length];
    hands[seat]!.add(deck[i]);
  }

  for (final hand in hands.values) {
    hand.sort((a, b) {
      final suitCompare = a.suit.index.compareTo(b.suit.index);
      return suitCompare != 0 ? suitCompare : a.compareTo(b);
    });
  }

  return hands;
}
