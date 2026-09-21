import '../models/card.dart';
import '../models/suit.dart';
import '../models/trick.dart';

/// Determines which cards in [hand] are legal to play right now, per
/// docs/RULES.md §4:
/// - must follow the suit led if able
/// - spades can't be led until broken, unless the hand is all spades
List<PlayingCard> legalPlays({
  required List<PlayingCard> hand,
  required Trick trick,
  required bool spadesBroken,
}) {
  assert(hand.isNotEmpty, 'Cannot compute legal plays for an empty hand');

  final leadSuit = trick.leadSuit;

  if (leadSuit == null) {
    // Leading the trick.
    final allSpades = hand.every((c) => c.isSpade);
    if (spadesBroken || allSpades) return List.unmodifiable(hand);
    final nonSpades = hand.where((c) => !c.isSpade).toList();
    return List.unmodifiable(nonSpades);
  }

  final followingSuit = hand.where((c) => c.suit == leadSuit).toList();
  if (followingSuit.isNotEmpty) return List.unmodifiable(followingSuit);

  // Void in the led suit: any card, including spades, is legal.
  return List.unmodifiable(hand);
}

/// Whether playing [card] as a discard/void play would break spades.
bool breaksSpades(PlayingCard card, {required Suit? leadSuit}) =>
    card.isSpade && leadSuit != null && leadSuit != Suit.spades;
