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
    this.progressiveDealing = false,
  });

  /// Progressive Spades per docs/RULES.md §7: hand size grows from 1 card
  /// to 13 over exactly 13 hands (instead of always dealing 13), with no
  /// Nil and no bag penalty.
  const MatchConfig.progressive()
    : targetScore = 500,
      lossFloor = -200,
      nilEnabled = false,
      blindNilEnabled = false,
      bostonBonusEnabled = false,
      bagPenaltyEvery = 10,
      bagPenaltyAmount = 0,
      progressiveDealing = true;

  /// First hand-end where a team's score reaches this ends the match.
  /// Ignored when [progressiveDealing] is true — that variant always runs
  /// exactly 13 hands regardless of score.
  final int targetScore;

  /// A team whose score falls to or below this loses instantly. Ignored
  /// when [progressiveDealing] is true.
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

  /// When true, hand size ramps 1→13 across the match instead of always
  /// dealing 13 cards per player (docs/RULES.md §7 "Progressive Spades").
  final bool progressiveDealing;
}
