import 'package:flutter/material.dart';

import '../../core/engine/match_state.dart';
import '../../core/engine/scoring.dart';
import '../../core/models/seat.dart';
import '../theme/app_theme.dart';

/// Small always-visible button that opens [ScoreHistoryDialog] — lets the
/// player review the running score and hand-by-hand history at any time,
/// not just at the end of a hand.
class ScoreHistoryButton extends StatelessWidget {
  const ScoreHistoryButton({super.key, required this.match});

  final MatchState match;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.25),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => ScoreHistoryDialog(match: match),
        ),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(
            Icons.leaderboard_rounded,
            color: AppColors.gold,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Full score review: running totals plus a hand-by-hand breakdown of
/// every completed hand this match.
class ScoreHistoryDialog extends StatelessWidget {
  const ScoreHistoryDialog({super.key, required this.match});

  final MatchState match;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.feltMid,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Scoreboard',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.cream),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _totalTile('You & North', Team.southNorth),
                  _totalTile('West & East', Team.westEast),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: AppColors.gold.withValues(alpha: 0.4), height: 1),
              const SizedBox(height: 8),
              Expanded(
                child: match.handHistory.isEmpty
                    ? const Center(
                        child: Text(
                          'No hands completed yet.',
                          style: TextStyle(color: AppColors.cream),
                        ),
                      )
                    : ListView.separated(
                        itemCount: match.handHistory.length,
                        separatorBuilder: (_, __) => Divider(
                          color: AppColors.cream.withValues(alpha: 0.12),
                          height: 16,
                        ),
                        itemBuilder: (context, index) => _HandRow(
                          round: index + 1,
                          results: match.handHistory[index],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalTile(String label, Team team) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.cream, fontSize: 12),
        ),
        Text(
          '${match.teamScores[team]}',
          style: const TextStyle(
            color: AppColors.cream,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          'bags ${match.teamBags[team]}',
          style: TextStyle(
            color: AppColors.cream.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _HandRow extends StatelessWidget {
  const _HandRow({required this.round, required this.results});

  final int round;
  final Map<Team, TeamHandScore> results;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '$round',
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(child: _teamCell(results[Team.southNorth]!)),
        const SizedBox(width: 8),
        Expanded(child: _teamCell(results[Team.westEast]!)),
      ],
    );
  }

  Widget _teamCell(TeamHandScore score) {
    final sign = score.totalDelta >= 0 ? '+' : '';
    return Text(
      'bid ${score.teamBid} · won ${score.teamTricksWon} · $sign${score.totalDelta}',
      style: const TextStyle(color: AppColors.cream, fontSize: 12),
    );
  }
}
