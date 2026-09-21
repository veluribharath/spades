import 'package:flutter_test/flutter_test.dart';
import 'package:spades_app/core/engine/trick_resolver.dart';
import 'package:spades_app/core/models/card.dart';
import 'package:spades_app/core/models/rank.dart';
import 'package:spades_app/core/models/seat.dart';
import 'package:spades_app/core/models/suit.dart';
import 'package:spades_app/core/models/trick.dart';

void main() {
  test('highest card of suit led wins when no spades played', () {
    final trick = Trick(leader: Seat.south)
      ..play(Seat.south, const PlayingCard(Suit.hearts, Rank.five))
      ..play(Seat.west, const PlayingCard(Suit.hearts, Rank.king))
      ..play(Seat.north, const PlayingCard(Suit.clubs, Rank.ace))
      ..play(Seat.east, const PlayingCard(Suit.hearts, Rank.two));

    expect(resolveTrick(trick), Seat.west);
  });

  test('any spade beats any non-spade card', () {
    final trick = Trick(leader: Seat.south)
      ..play(Seat.south, const PlayingCard(Suit.hearts, Rank.ace))
      ..play(Seat.west, const PlayingCard(Suit.spades, Rank.two))
      ..play(Seat.north, const PlayingCard(Suit.hearts, Rank.king))
      ..play(Seat.east, const PlayingCard(Suit.hearts, Rank.queen));

    expect(resolveTrick(trick), Seat.west);
  });

  test('highest spade wins when multiple spades played', () {
    final trick = Trick(leader: Seat.south)
      ..play(Seat.south, const PlayingCard(Suit.spades, Rank.three))
      ..play(Seat.west, const PlayingCard(Suit.spades, Rank.jack))
      ..play(Seat.north, const PlayingCard(Suit.spades, Rank.two))
      ..play(Seat.east, const PlayingCard(Suit.spades, Rank.ten));

    expect(resolveTrick(trick), Seat.west);
  });
}
