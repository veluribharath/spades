import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engine/match_state.dart';
import '../../core/engine/trick_resolver.dart';
import '../../core/models/seat.dart';
import '../../state/game_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/bid_dialog.dart';
import '../widgets/hand_fan.dart';
import '../widgets/score_history_dialog.dart';
import '../widgets/scoreboard_bar.dart';
import '../widgets/trick_area.dart';

class TableScreen extends ConsumerWidget {
  const TableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(gameControllerProvider);
    final match = controller.match;
    final trick = controller.visibleTrick;
    final plays = trick?.plays ?? const [];

    return Scaffold(
      body: DecoratedBox(
        decoration: feltTableDecoration(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                child: ScoreboardBar(
                  teamScores: match.teamScores,
                  teamBags: match.teamBags,
                  config: match.config,
                  roundNumber: match.roundNumber,
                  handSize: match.handSize,
                  trailing: ScoreHistoryButton(match: match),
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: const Alignment(0, -0.95),
                      child: _OpponentSeat(seat: Seat.north, match: match),
                    ),
                    Align(
                      alignment: const Alignment(-0.94, -0.62),
                      child: _OpponentSeat(seat: Seat.west, match: match),
                    ),
                    Align(
                      alignment: const Alignment(0.94, -0.62),
                      child: _OpponentSeat(seat: Seat.east, match: match),
                    ),
                    TrickArea(
                      plays: {for (final e in plays) e.key: e.value},
                      winner: plays.isEmpty ? null : currentWinner(trick!),
                    ),
                    if (controller.isHumanBidTurn)
                      BidPanel(
                        config: match.config,
                        handSize: match.handSize,
                        maxBid: match.maxBidFor(kHumanSeat),
                        partnerBid: match.bids[kHumanSeat.partner],
                        isFirstBidOfHand: match.bids.isEmpty,
                        blindNilEligible: match.config.blindNilEnabled,
                        onBid: controller.submitHumanBid,
                      ),
                    if (match.phase == HandPhase.complete)
                      _HandSummaryOverlay(controller: controller),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HumanSeat(controller: controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _seatName(Seat seat) => switch (seat) {
  Seat.south => 'You',
  Seat.west => 'West',
  Seat.north => 'North',
  Seat.east => 'East',
};

/// "bid 2 · won 1" while playing, "bid 2" while bidding, nothing before
/// the seat has bid.
String? _bidSummary(MatchState match, Seat seat) {
  final bid = match.bids[seat];
  if (bid == null) return null;
  if (match.phase == HandPhase.bidding) return 'bid $bid';
  return 'bid $bid · won ${match.tricksWonThisHand[seat] ?? 0}';
}

class _OpponentSeat extends StatelessWidget {
  const _OpponentSeat({required this.seat, required this.match});

  final Seat seat;
  final MatchState match;

  @override
  Widget build(BuildContext context) {
    final isTurn =
        (match.phase == HandPhase.bidding && match.nextBidder == seat) ||
        (match.phase == HandPhase.playing &&
            match.currentTrick!.nextToPlay == seat);

    final tag = _SeatTag(
      name: _seatName(seat),
      detail: _bidSummary(match, seat),
      acting: isTurn,
    );
    // Only North (across the table) shows its hand; the side seats stay
    // a single tag so they never crowd the trick.
    if (seat != Seat.north) return tag;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tag,
        const SizedBox(height: 10),
        _MiniBacks(count: match.hands[seat]!.length),
      ],
    );
  }
}

/// An opponent's hand as a tidy stack of small card backs — present, but
/// never louder than the cards in play.
class _MiniBacks extends StatelessWidget {
  const _MiniBacks({required this.count});

  final int count;

  static const _w = 26.0;
  static const _h = 36.0;
  static const _step = 10.0;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox(height: _h);
    return SizedBox(
      width: _w + _step * (count - 1),
      height: _h,
      child: Stack(
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: _step * i,
              child: Container(
                width: _w,
                height: _h,
                decoration: BoxDecoration(
                  color: AppColors.feltRaised,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.brass.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Seat tag: a tint pill at rest; a brass hairline with a brass dot while
/// a bot is thinking.
class _SeatTag extends StatelessWidget {
  const _SeatTag({required this.name, this.detail, required this.acting});

  final String name;
  final String? detail;
  final bool acting;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.quick,
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.tint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: acting ? AppColors.brass : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (acting) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.brass,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(name, style: AppText.ui(size: 12, weight: FontWeight.w600)),
          if (detail != null) ...[
            const SizedBox(width: 8),
            Text(detail!, style: AppText.ui(size: 12, color: AppColors.sage)),
          ],
        ],
      ),
    );
  }
}

class _HumanSeat extends StatelessWidget {
  const _HumanSeat({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    final hand = match.hands[kHumanSeat]!;
    final bid = match.bids[kHumanSeat];
    final acting = controller.isHumanBidTurn || controller.isHumanPlayTurn;

    String? turnLabel;
    if (controller.isHumanBidTurn) {
      turnLabel = 'Your turn to bid';
    } else if (controller.isHumanPlayTurn) {
      final lead = match.currentTrick?.leadSuit;
      turnLabel = lead == null
          ? 'Your turn · lead'
          : hand.any((c) => c.suit == lead)
          ? 'Your turn · follow ${lead.name}'
          : 'Your turn';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (acting)
          _YourTurnPill(label: turnLabel!)
        else
          _SeatTag(
            name: 'You',
            detail: _bidSummary(match, kHumanSeat),
            acting: false,
          ),
        if (acting && bid != null) ...[
          const SizedBox(height: 8),
          Text(
            'You bid $bid · won ${match.tricksWonThisHand[kHumanSeat] ?? 0}',
            style: AppText.ui(size: 12, color: AppColors.sage),
          ),
        ],
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: HandFan(
              cards: hand,
              faceUp: true,
              cardWidth: 66,
              legalCards: controller.isHumanPlayTurn
                  ? controller.legalHumanCards
                  : null,
              onCardTap: controller.playHumanCard,
            ),
          ),
        ),
      ],
    );
  }
}

/// The one solid brass element on the table: it only appears when the
/// game is waiting on you.
class _YourTurnPill extends StatelessWidget {
  const _YourTurnPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.brass,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: AppText.ui(
            size: 12,
            weight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _HandSummaryOverlay extends StatelessWidget {
  const _HandSummaryOverlay({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    final results = match.handHistory.last;
    final finished = match.status == MatchStatus.finished;

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.felt.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.brass.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 48,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            finished
                ? (match.winner == Team.southNorth
                      ? 'You win the match'
                      : 'West & East win')
                : 'Round ${match.roundNumber} complete',
            style: AppText.display(size: 30),
          ),
          const SizedBox(height: 18),
          for (final team in Team.values) ...[
            _SummaryRow(
              label: team == Team.southNorth ? 'You & North' : 'West & East',
              bid: results[team]!.teamBid,
              won: results[team]!.teamTricksWon,
              delta: results[team]!.totalDelta,
              total: match.teamScores[team]!,
            ),
            if (team == Team.southNorth)
              const Divider(height: 1, color: AppColors.hairline),
          ],
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: finished
                ? () => Navigator.pop(context)
                : controller.startNextHand,
            child: Text(finished ? 'Back to menu' : 'Next hand'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.bid,
    required this.won,
    required this.delta,
    required this.total,
  });

  final String label;
  final int bid;
  final int won;
  final int delta;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: AppText.label(size: 10)),
                const SizedBox(height: 4),
                Text(
                  'bid $bid · won $won',
                  style: AppText.ui(size: 13, color: AppColors.sage),
                ),
              ],
            ),
          ),
          Text(
            formatDelta(delta),
            style: AppText.display(
              size: 24,
              color: delta < 0 ? AppColors.loss : AppColors.text,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 56,
            child: Text(
              formatScore(total),
              textAlign: TextAlign.end,
              style: AppText.display(size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
