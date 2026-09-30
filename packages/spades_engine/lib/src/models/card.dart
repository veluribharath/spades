import 'rank.dart';
import 'suit.dart';

/// An immutable playing card.
class PlayingCard implements Comparable<PlayingCard> {
  const PlayingCard(this.suit, this.rank);

  final Suit suit;
  final Rank rank;

  bool get isSpade => suit == Suit.spades;

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => Object.hash(suit, rank);

  /// Only meaningful for cards of the same suit; trick resolution handles
  /// cross-suit/trump comparison separately (see [trick_resolver.dart]).
  @override
  int compareTo(PlayingCard other) => rank.value.compareTo(other.rank.value);

  @override
  String toString() => '${rank.label}${suit.symbol}';
}

/// A full, unshuffled 52-card deck.
List<PlayingCard> buildStandardDeck() => [
  for (final suit in Suit.values)
    for (final rank in Rank.values) PlayingCard(suit, rank),
];
