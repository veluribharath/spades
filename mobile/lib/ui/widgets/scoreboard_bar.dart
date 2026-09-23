import 'package:flutter/material.dart';

import '../../core/models/match_config.dart';
import '../../core/models/seat.dart';
import '../theme/app_theme.dart';

/// The table HUD: each partnership's score at the edges, the round in
/// brass in the middle. No panel behind it — the numbers sit on the felt.
class ScoreboardBar extends StatelessWidget {
  const ScoreboardBar({
    super.key,
    required this.teamScores,
    required this.teamBags,
    required this.config,
    required this.roundNumber,
    required this.handSize,
    this.trailing,
  });

  final Map<Team, int> teamScores;
  final Map<Team, int> teamBags;
  final MatchConfig config;
  final int roundNumber;
  final int handSize;

  /// Optional widget after the right-hand score (the scoreboard button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final subtitle = config.progressiveDealing
        ? '$handSize card${handSize == 1 ? '' : 's'} · of 13'
        : 'to ${config.targetScore}';

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: _TeamScore(
              label: 'You & North',
              score: teamScores[Team.southNorth]!,
              alignEnd: false,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Round $roundNumber',
                style: AppText.display(size: 18, color: AppColors.brass),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppText.ui(size: 11, color: AppColors.sage),
              ),
            ],
          ),
          Expanded(
            child: _TeamScore(
              label: 'West & East',
              score: teamScores[Team.westEast]!,
              alignEnd: true,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

class _TeamScore extends StatelessWidget {
  const _TeamScore({
    required this.label,
    required this.score,
    required this.alignEnd,
  });

  final String label;
  final int score;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: AppText.label(size: 10),
        ),
        const SizedBox(height: 4),
        Text(formatScore(score), style: AppText.display(size: 28)),
      ],
    );
  }
}

/// Scores use a true minus sign so negatives line up with the serif digits.
String formatScore(int value) => value < 0 ? '−${-value}' : '$value';

/// Deltas always carry a sign: +31, −19, 0.
String formatDelta(int value) => value > 0
    ? '+$value'
    : value < 0
    ? '−${-value}'
    : '0';
