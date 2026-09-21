import 'dart:math';

import '../models/card.dart';
import '../models/seat.dart';

/// Shuffles a standard deck and deals 13 cards to each of the 4 seats,
/// per docs/RULES.md §2. [random] is injectable for deterministic tests.
Map<Seat, List<PlayingCard>> dealHand({Random? random}) {
  final deck = buildStandardDeck()..shuffle(random ?? Random());
  final hands = {for (final seat in Seat.values) seat: <PlayingCard>[]};

  for (var i = 0; i < deck.length; i++) {
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
