import 'package:flutter_test/flutter_test.dart';
import 'package:spades_app/core/engine/legal_plays.dart';
import 'package:spades_app/core/models/card.dart';
import 'package:spades_app/core/models/rank.dart';
import 'package:spades_app/core/models/seat.dart';
import 'package:spades_app/core/models/suit.dart';
import 'package:spades_app/core/models/trick.dart';

const cAceH = PlayingCard(Suit.hearts, Rank.ace);
const c2H = PlayingCard(Suit.hearts, Rank.two);
const c2S = PlayingCard(Suit.spades, Rank.two);
const cKS = PlayingCard(Suit.spades, Rank.king);
const c2C = PlayingCard(Suit.clubs, Rank.two);

void main() {
  group('leading', () {
    test('cannot lead spades before broken if hand has other suits', () {
      final hand = [c2H, c2S, cKS];
      final trick = Trick(leader: Seat.south);
      final legal = legalPlays(hand: hand, trick: trick, spadesBroken: false);
      expect(legal, containsAll([c2H]));
      expect(legal, isNot(contains(c2S)));
      expect(legal, isNot(contains(cKS)));
    });

    test('can lead spades once broken', () {
      final hand = [c2H, c2S];
      final trick = Trick(leader: Seat.south);
      final legal = legalPlays(hand: hand, trick: trick, spadesBroken: true);
      expect(legal, containsAll([c2H, c2S]));
    });

    test('can lead spades with an all-spade hand even if unbroken', () {
      final hand = [c2S, cKS];
      final trick = Trick(leader: Seat.south);
      final legal = legalPlays(hand: hand, trick: trick, spadesBroken: false);
      expect(legal, containsAll([c2S, cKS]));
    });
  });

  group('following', () {
    test('must follow suit when able', () {
      final hand = [cAceH, c2H, c2S];
      final trick = Trick(leader: Seat.west)..play(Seat.west, c2C);
      // c2C is clubs, hand has no clubs -> should be free choice.
      final legal = legalPlays(hand: hand, trick: trick, spadesBroken: false);
      expect(legal, containsAll([cAceH, c2H, c2S]));
    });

    test('restricted to suit led when player holds it', () {
      final hand = [cAceH, c2H, c2S];
      final trick = Trick(leader: Seat.west)..play(Seat.west, c2H);
      final legal = legalPlays(hand: hand, trick: trick, spadesBroken: false);
      expect(legal, containsAll([cAceH, c2H]));
      expect(legal, isNot(contains(c2S)));
    });
  });
}
