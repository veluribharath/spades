import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spades_app/core/engine/dealer.dart';
import 'package:spades_app/core/models/seat.dart';

void main() {
  test('deals 13 unique cards to each of the 4 seats', () {
    final hands = dealHand(random: Random(42));

    expect(hands.keys.toSet(), Seat.values.toSet());
    for (final seat in Seat.values) {
      expect(hands[seat], hasLength(13));
    }

    final allCards = hands.values.expand((h) => h).toSet();
    expect(allCards, hasLength(52), reason: 'no duplicate cards across hands');
  });

  test('is deterministic given the same seeded Random', () {
    final a = dealHand(random: Random(7));
    final b = dealHand(random: Random(7));
    for (final seat in Seat.values) {
      expect(a[seat], equals(b[seat]));
    }
  });

  test('hands are sorted by suit then rank', () {
    final hands = dealHand(random: Random(1));
    for (final hand in hands.values) {
      for (var i = 1; i < hand.length; i++) {
        final prev = hand[i - 1];
        final curr = hand[i];
        if (prev.suit == curr.suit) {
          expect(prev.rank.value, lessThan(curr.rank.value));
        } else {
          expect(prev.suit.index, lessThan(curr.suit.index));
        }
      }
    }
  });
}
