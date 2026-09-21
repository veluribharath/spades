import '../models/bid.dart';
import '../models/match_config.dart';
import '../models/seat.dart';

/// One player's bid + trick outcome for a finished hand.
class PlayerHandResult {
  const PlayerHandResult({
    required this.seat,
    required this.bid,
    required this.tricksWon,
  });

  final Seat seat;
  final Bid bid;
  final int tricksWon;
}

/// The full scoring breakdown for one team's hand, per docs/RULES.md §5.
class TeamHandScore {
  const TeamHandScore({
    required this.team,
    required this.teamBid,
    required this.teamTricksWon,
    required this.madeContract,
    required this.contractScore,
    required this.nilScore,
    required this.bostonBonus,
    required this.bagsEarned,
    required this.bagCountBefore,
    required this.bagCountAfter,
    required this.bagPenalty,
  });

  final Team team;
  final int teamBid;
  final int teamTricksWon;
  final bool madeContract;
  final int contractScore;
  final int nilScore;
  final int bostonBonus;
  final int bagsEarned;
  final int bagCountBefore;
  final int bagCountAfter;
  final int bagPenalty;

  int get totalDelta =>
      contractScore + bagsEarned + nilScore + bostonBonus - bagPenalty;
}

/// Computes one team's score for a completed hand, per docs/RULES.md §5.
/// [bagCountBefore] is the team's cumulative bag count carried in from
/// previous hands; the bag-penalty threshold check uses it.
TeamHandScore computeTeamHandScore({
  required Team team,
  required List<PlayerHandResult> players,
  required int bagCountBefore,
  required MatchConfig config,
}) {
  assert(players.length == 2, 'A team has exactly 2 players');
  assert(players.every((p) => p.seat.team == team));

  final teamBid = players.fold<int>(0, (sum, p) => sum + p.bid.teamTricks);
  final teamTricksWon = players.fold<int>(0, (sum, p) => sum + p.tricksWon);

  final madeContract = teamTricksWon >= teamBid;
  final contractScore = madeContract ? 10 * teamBid : -10 * teamBid;
  final bagsEarned = madeContract ? teamTricksWon - teamBid : 0;

  final nilScore = players.fold<int>(0, (sum, p) {
    if (!p.bid.isNil) return sum;
    final success = p.tricksWon == 0;
    final magnitude = p.bid.isBlind ? 200 : 100;
    return sum + (success ? magnitude : -magnitude);
  });

  final bostonBonus = (config.bostonBonusEnabled && teamTricksWon == 13)
      ? config.bostonBonusAmount
      : 0;

  final bagCountAfter = bagCountBefore + bagsEarned;
  final penaltyCrossings =
      (bagCountAfter ~/ config.bagPenaltyEvery) -
      (bagCountBefore ~/ config.bagPenaltyEvery);
  final bagPenalty = penaltyCrossings * config.bagPenaltyAmount;

  return TeamHandScore(
    team: team,
    teamBid: teamBid,
    teamTricksWon: teamTricksWon,
    madeContract: madeContract,
    contractScore: contractScore,
    nilScore: nilScore,
    bostonBonus: bostonBonus,
    bagsEarned: bagsEarned,
    bagCountBefore: bagCountBefore,
    bagCountAfter: bagCountAfter,
    bagPenalty: bagPenalty,
  );
}
