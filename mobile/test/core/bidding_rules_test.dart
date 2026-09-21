import 'package:flutter_test/flutter_test.dart';
import 'package:spades_app/core/engine/bidding_rules.dart';
import 'package:spades_app/core/models/bid.dart';
import 'package:spades_app/core/models/match_config.dart';

void main() {
  test('nil bid rejected when nil is disabled', () {
    expect(
      () => validateBid(
        Bid.nil(),
        config: const MatchConfig(nilEnabled: false),
        isFirstBidOfHand: true,
        biddingTeamScore: 0,
        opposingTeamScore: 0,
        handSize: 13,
      ),
      throwsA(isA<IllegalBidException>()),
    );
  });

  test('regular bid always allowed', () {
    expect(
      () => validateBid(
        Bid.regular(4),
        config: const MatchConfig(nilEnabled: false),
        isFirstBidOfHand: false,
        biddingTeamScore: 0,
        opposingTeamScore: 0,
        handSize: 13,
      ),
      returnsNormally,
    );
  });

  group('hand-size cap', () {
    test('rejects a bid higher than the cards dealt this hand', () {
      expect(
        () => validateBid(
          Bid.regular(3),
          config: const MatchConfig(),
          isFirstBidOfHand: true,
          biddingTeamScore: 0,
          opposingTeamScore: 0,
          handSize: 2,
        ),
        throwsA(isA<IllegalBidException>()),
      );
    });

    test('allows a bid equal to the cards dealt this hand', () {
      expect(
        () => validateBid(
          Bid.regular(2),
          config: const MatchConfig(),
          isFirstBidOfHand: true,
          biddingTeamScore: 0,
          opposingTeamScore: 0,
          handSize: 2,
        ),
        returnsNormally,
      );
    });
  });

  group('blind nil', () {
    const config = MatchConfig(blindNilEnabled: true);

    test('rejected when not the first bid of the hand', () {
      expect(
        () => validateBid(
          Bid.blindNil(),
          config: config,
          isFirstBidOfHand: false,
          biddingTeamScore: 0,
          opposingTeamScore: 200,
          handSize: 13,
        ),
        throwsA(isA<IllegalBidException>()),
      );
    });

    test('rejected when not at least 100 points behind', () {
      expect(
        () => validateBid(
          Bid.blindNil(),
          config: config,
          isFirstBidOfHand: true,
          biddingTeamScore: 50,
          opposingTeamScore: 100,
          handSize: 13,
        ),
        throwsA(isA<IllegalBidException>()),
      );
    });

    test('allowed when first bid and 100+ behind', () {
      expect(
        () => validateBid(
          Bid.blindNil(),
          config: config,
          isFirstBidOfHand: true,
          biddingTeamScore: 0,
          opposingTeamScore: 100,
          handSize: 13,
        ),
        returnsNormally,
      );
    });

    test('rejected outright when blind nil disabled', () {
      expect(
        () => validateBid(
          Bid.blindNil(),
          config: const MatchConfig(),
          isFirstBidOfHand: true,
          biddingTeamScore: 0,
          opposingTeamScore: 500,
          handSize: 13,
        ),
        throwsA(isA<IllegalBidException>()),
      );
    });
  });
}
