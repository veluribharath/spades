/// Tunable rules for a match, matching the toggles listed in
/// docs/RULES.md §6-7. Classic Partnership Spades is the default.
class MatchConfig {
  const MatchConfig({
    this.targetScore = 500,
    this.lossFloor = -200,
    this.nilEnabled = true,
    this.blindNilEnabled = false,
    this.bostonBonusEnabled = false,
    this.bagPenaltyEvery = 10,
    this.bagPenaltyAmount = 100,
  });

  /// First hand-end where a team's score reaches this ends the match.
  final int targetScore;

  /// A team whose score falls to or below this loses instantly.
  final int lossFloor;

  final bool nilEnabled;
  final bool blindNilEnabled;

  /// Whether winning all 13 tricks in a hand awards a bonus (house rule,
  /// off by default per docs/RULES.md §5.4).
  final bool bostonBonusEnabled;

  /// Points awarded for a Boston (13-trick shutout) when enabled.
  final int bostonBonusAmount = 100;

  /// A team is penalized every time its cumulative bag count reaches a
  /// multiple of this many bags (default 10, per §5.2).
  final int bagPenaltyEvery;

  /// Points lost each time the bag penalty triggers (default -100).
  final int bagPenaltyAmount;
}
