import 'package:flutter/material.dart';

import '../../core/models/match_config.dart';
import '../../core/models/seat.dart';
import '../theme/app_theme.dart';

/// Compact HUD bar showing both teams' running score and bag count.
class ScoreboardBar extends StatelessWidget {
  const ScoreboardBar({
    super.key,
    required this.teamScores,
    required this.teamBags,
    required this.config,
    required this.roundNumber,
    required this.handSize,
  });

  final Map<Team, int> teamScores;
  final Map<Team, int> teamBags;
  final MatchConfig config;
  final int roundNumber;
  final int handSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _teamTile('You & North', Team.southNorth),
            Text(
              config.progressiveDealing
                  ? 'Round $roundNumber/13 · $handSize card${handSize == 1 ? '' : 's'}'
                  : 'to ${config.targetScore}',
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            _teamTile('West & East', Team.westEast),
          ],
        ),
      ),
    );
  }

  Widget _teamTile(String label, Team team) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.cream),
        ),
        Text(
          '${teamScores[team]}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.cream,
          ),
        ),
        Text(
          'bags ${teamBags[team]}',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.cream.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
