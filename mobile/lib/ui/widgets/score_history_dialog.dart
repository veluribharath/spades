import 'package:flutter/material.dart';

import '../../core/engine/match_state.dart';
import '../../core/engine/scoring.dart';
import '../../core/models/seat.dart';
import '../theme/app_theme.dart';
import 'scoreboard_bar.dart';

/// A quiet round icon button (tint fill, no border) — the design
/// language's secondary action.
class TintIconButton extends StatelessWidget {
  const TintIconButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.tooltip,
  });

  final Widget child;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.tint,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(dimension: 44, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// Always-visible button that opens [ScoreHistoryDialog] — lets the
/// player review the running score and hand-by-hand history at any time,
/// not just at the end of a hand.
class ScoreHistoryButton extends StatelessWidget {
  const ScoreHistoryButton({super.key, required this.match});

  final MatchState match;

  @override
  Widget build(BuildContext context) {
    return TintIconButton(
      tooltip: 'Scoreboard',
      onPressed: () => showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (_) => ScoreHistoryDialog(match: match),
      ),
      child: const CustomPaint(
        size: Size.square(18),
        painter: _BarsIconPainter(),
      ),
    );
  }
}

/// Three rising bars in brass — the scoreboard glyph from the design.
class _BarsIconPainter extends CustomPainter {
  const _BarsIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 18;
    final paint = Paint()
      ..color = AppColors.brass
      ..strokeWidth = 1.6 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(3 * s, 15 * s), Offset(3 * s, 9 * s), paint);
    canvas.drawLine(Offset(9 * s, 15 * s), Offset(9 * s, 3 * s), paint);
    canvas.drawLine(Offset(15 * s, 15 * s), Offset(15 * s, 11 * s), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Full score review: running totals plus a hand-by-hand breakdown of
/// every completed hand this match.
class ScoreHistoryDialog extends StatelessWidget {
  const ScoreHistoryDialog({super.key, required this.match});

  final MatchState match;

  @override
  Widget build(BuildContext context) {
    final us = match.teamScores[Team.southNorth]!;
    final them = match.teamScores[Team.westEast]!;

    return Dialog(
      backgroundColor: AppColors.felt,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.hairline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Scoreboard', style: AppText.display(size: 36)),
                  TintIconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _TotalCard(
                        label: 'You & North',
                        score: us,
                        bags: match.teamBags[Team.southNorth]!,
                        leadBy: us - them,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TotalCard(
                        label: 'West & East',
                        score: them,
                        bags: match.teamBags[Team.westEast]!,
                        leadBy: them - us,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Row(
                  children: [
                    SizedBox(width: 40, child: Text('RD', style: _header)),
                    Expanded(child: Text('US · BID / WON', style: _header)),
                    Expanded(child: Text('THEM · BID / WON', style: _header)),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.hairline),
              Flexible(
                child: match.handHistory.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No hands completed yet.',
                          textAlign: TextAlign.center,
                          style: AppText.ui(size: 14, color: AppColors.sage),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: match.handHistory.length,
                        itemBuilder: (context, index) => _HandRow(
                          round: index + 1,
                          results: match.handHistory[index],
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              Text(
                'A set hand scores −10 per trick bid, plus 1 for each '
                'trick won.',
                style: AppText.ui(size: 12, color: AppColors.sage, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final _header = AppText.label(size: 10);
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.score,
    required this.bags,
    required this.leadBy,
  });

  final String label;
  final int score;
  final int bags;
  final int leadBy;

  @override
  Widget build(BuildContext context) {
    final leading = leadBy > 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: leading ? AppColors.brass : AppColors.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.label(size: 10)),
          const SizedBox(height: 8),
          Text(formatScore(score), style: AppText.display(size: 44)),
          const SizedBox(height: 8),
          Text(
            '$bags bag${bags == 1 ? '' : 's'}'
            '${leading ? ' · leading by $leadBy' : ''}',
            style: AppText.ui(size: 12, color: AppColors.sage),
          ),
        ],
      ),
    );
  }
}

class _HandRow extends StatelessWidget {
  const _HandRow({required this.round, required this.results});

  final int round;
  final Map<Team, TeamHandScore> results;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.tint)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '$round',
              style: AppText.display(size: 20, color: AppColors.brass),
            ),
          ),
          Expanded(child: _teamCell(results[Team.southNorth]!)),
          Expanded(child: _teamCell(results[Team.westEast]!)),
        ],
      ),
    );
  }

  Widget _teamCell(TeamHandScore score) {
    final delta = score.totalDelta;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '${score.teamBid} / ${score.teamTricksWon}',
          style: AppText.ui(size: 13, color: AppColors.sage),
        ),
        const SizedBox(width: 10),
        Text(
          formatDelta(delta),
          style: AppText.display(
            size: 20,
            color: delta < 0 ? AppColors.loss : AppColors.text,
          ),
        ),
      ],
    );
  }
}
