import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engine/match_state.dart';
import '../../core/models/bid.dart';
import '../../core/models/seat.dart';
import '../../state/game_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/bid_dialog.dart';
import '../widgets/hand_fan.dart';
import '../widgets/scoreboard_bar.dart';
import '../widgets/trick_area.dart';

class TableScreen extends ConsumerWidget {
  const TableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(gameControllerProvider);
    final match = controller.match;

    return Scaffold(
      body: DecoratedBox(
        decoration: feltTableDecoration(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ScoreboardBar(
                  teamScores: match.teamScores,
                  teamBags: match.teamBags,
                  config: match.config,
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: const Alignment(0, -0.82),
                      child: _OpponentSeat(
                        seat: Seat.north,
                        match: match,
                        horizontal: true,
                      ),
                    ),
                    Align(
                      alignment: const Alignment(-0.88, 0),
                      child: _OpponentSeat(
                        seat: Seat.west,
                        match: match,
                        horizontal: false,
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0.88, 0),
                      child: _OpponentSeat(
                        seat: Seat.east,
                        match: match,
                        horizontal: false,
                      ),
                    ),
                    TrickArea(
                      plays: {
                        for (final e
                            in (controller.visibleTrick?.plays ?? const []))
                          e.key: e.value,
                      },
                    ),
                    if (controller.isHumanBidTurn)
                      BidPanel(
                        config: match.config,
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _HumanSeat(controller: controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpponentSeat extends StatelessWidget {
  const _OpponentSeat({
    required this.seat,
    required this.match,
    required this.horizontal,
  });

  final Seat seat;
  final MatchState match;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final hand = match.hands[seat]!;
    final bid = match.bids[seat];
    final tricks = match.tricksWonThisHand[seat];
    final isTurn =
        (match.phase == HandPhase.bidding && match.nextBidder == seat) ||
        (match.phase == HandPhase.playing &&
            match.currentTrick!.nextToPlay == seat);

    final fan = RotatedBox(
      quarterTurns: horizontal ? 0 : 1,
      child: HandFan(cards: hand, faceUp: false, cardWidth: 40),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SeatLabel(seat: seat, bid: bid, tricks: tricks, isTurn: isTurn),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 90),
          child: FittedBox(fit: BoxFit.contain, child: fan),
        ),
      ],
    );
  }
}

class _SeatLabel extends StatelessWidget {
  const _SeatLabel({
    required this.seat,
    required this.bid,
    required this.tricks,
    required this.isTurn,
  });

  final Seat seat;
  final Bid? bid;
  final int? tricks;
  final bool isTurn;

  @override
  Widget build(BuildContext context) {
    final name = switch (seat) {
      Seat.south => 'You',
      Seat.west => 'West',
      Seat.north => 'North',
      Seat.east => 'East',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isTurn
            ? AppColors.seatHighlight.withValues(alpha: 0.9)
            : Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        bid == null
            ? name
            : '$name · $bid${tricks != null ? " ($tricks)" : ""}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isTurn ? AppColors.spadeInk : AppColors.cream,
        ),
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
    final tricks = match.tricksWonThisHand[kHumanSeat];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SeatLabel(
          seat: kHumanSeat,
          bid: bid,
          tricks: tricks,
          isTurn: controller.isHumanBidTurn || controller.isHumanPlayTurn,
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
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
      ],
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
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            finished
                ? '${match.winner == Team.southNorth ? "You" : "West & East"} win the match!'
                : 'Hand complete',
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          for (final team in Team.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${team == Team.southNorth ? "You & North" : "West & East"}: '
                '${results[team]!.totalDelta >= 0 ? "+" : ""}${results[team]!.totalDelta} '
                '(total ${match.teamScores[team]})',
                style: const TextStyle(color: AppColors.cream),
              ),
            ),
          const SizedBox(height: 16),
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
