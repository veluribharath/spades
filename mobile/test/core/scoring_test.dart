import 'package:flutter_test/flutter_test.dart';
import 'package:spades_app/core/engine/scoring.dart';
import 'package:spades_app/core/models/bid.dart';
import 'package:spades_app/core/models/match_config.dart';
import 'package:spades_app/core/models/seat.dart';

void main() {
  const config = MatchConfig();

  test('made contract scores 10 per bid trick plus 1 per bag', () {
    final score = computeTeamHandScore(
      team: Team.southNorth,
      players: [
        PlayerHandResult(seat: Seat.south, bid: Bid.regular(4), tricksWon: 5),
        PlayerHandResult(seat: Seat.north, bid: Bid.regular(3), tricksWon: 3),
      ],
      bagCountBefore: 0,
      config: config,
    );

    expect(score.teamBid, 7);
    expect(score.teamTricksWon, 8);
    expect(score.madeContract, isTrue);
    expect(score.contractScore, 70);
    expect(score.bagsEarned, 1);
    expect(score.totalDelta, 71);
  });

  test('set contract loses 10 per bid trick with no partial credit', () {
    final score = computeTeamHandScore(
      team: Team.southNorth,
      players: [
        PlayerHandResult(seat: Seat.south, bid: Bid.regular(5), tricksWon: 2),
        PlayerHandResult(seat: Seat.north, bid: Bid.regular(3), tricksWon: 4),
      ],
      bagCountBefore: 0,
      config: config,
    );

    expect(score.teamBid, 8);
    expect(score.teamTricksWon, 6);
    expect(score.madeContract, isFalse);
    expect(score.contractScore, -80);
    expect(score.bagsEarned, 0);
    expect(score.totalDelta, -80);
  });

  test('successful nil adds +100 independent of team contract', () {
    final score = computeTeamHandScore(
      team: Team.southNorth,
      players: [
        PlayerHandResult(seat: Seat.south, bid: Bid.nil(), tricksWon: 0),
        PlayerHandResult(seat: Seat.north, bid: Bid.regular(4), tricksWon: 5),
      ],
      bagCountBefore: 0,
      config: config,
    );

    // Team bid = 0 (nil) + 4 = 4; team tricks = 0 + 5 = 5 -> made, 1 bag.
    expect(score.contractScore, 40);
    expect(score.nilScore, 100);
    expect(score.totalDelta, 141);
  });

  test('failed nil subtracts 100 and the tricks still count for the team', () {
    final score = computeTeamHandScore(
      team: Team.southNorth,
      players: [
        PlayerHandResult(seat: Seat.south, bid: Bid.nil(), tricksWon: 2),
        PlayerHandResult(seat: Seat.north, bid: Bid.regular(4), tricksWon: 4),
      ],
      bagCountBefore: 0,
      config: config,
    );

    expect(score.teamBid, 4);
    expect(score.teamTricksWon, 6);
    expect(score.contractScore, 40); // made 4, 2 bags
    expect(score.bagsEarned, 2);
    expect(score.nilScore, -100);
    expect(score.totalDelta, 40 + 2 - 100);
  });

  test('blind nil doubles the stakes to 200', () {
    final score = computeTeamHandScore(
      team: Team.southNorth,
      players: [
        PlayerHandResult(seat: Seat.south, bid: Bid.blindNil(), tricksWon: 0),
        PlayerHandResult(seat: Seat.north, bid: Bid.regular(3), tricksWon: 3),
      ],
      bagCountBefore: 0,
      config: config,
    );

    expect(score.nilScore, 200);
  });

  test('bag penalty triggers exactly when crossing a multiple of 10', () {
    final score = computeTeamHandScore(
      team: Team.southNorth,
      players: [
        PlayerHandResult(seat: Seat.south, bid: Bid.regular(2), tricksWon: 5),
        PlayerHandResult(seat: Seat.north, bid: Bid.regular(2), tricksWon: 4),
      ],
      bagCountBefore: 7, // 7 + 5 bags earned = 12 -> crosses 10 once.
      config: config,
    );

    expect(score.bagsEarned, 5);
    expect(score.bagCountAfter, 12);
    expect(score.bagPenalty, 100);
    expect(score.totalDelta, 40 + 5 - 100);
  });

  test('no bag penalty when staying under the next multiple of 10', () {
    final score = computeTeamHandScore(
      team: Team.southNorth,
      players: [
        PlayerHandResult(seat: Seat.south, bid: Bid.regular(2), tricksWon: 3),
        PlayerHandResult(seat: Seat.north, bid: Bid.regular(2), tricksWon: 2),
      ],
      bagCountBefore: 2,
      config: config,
    );

    expect(score.bagCountAfter, 3);
    expect(score.bagPenalty, 0);
  });
}
