import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spades_app/core/ai/bot_bidder.dart';
import 'package:spades_app/core/engine/match_state.dart';
import 'package:spades_app/state/game_controller.dart';

/// Regression test for a bug where the 4th card of a trick (and the
/// completed trick as a whole) never got its own rendered frame: the
/// engine resolves and replaces a completed trick synchronously inside
/// `MatchState.playCard`, so the UI must hold the finished trick on
/// screen for a beat rather than reading `match.currentTrick` directly.
void main() {
  testWidgets('a completed trick stays visible before the table clears it', (
    tester,
  ) async {
    final controller = GameController(random: Random(7));

    while (controller.match.phase == HandPhase.bidding) {
      if (controller.isHumanBidTurn) {
        controller.submitHumanBid(
          chooseBotBid(
            hand: controller.match.hands[kHumanSeat]!,
            config: controller.match.config,
            isFirstBidOfHand: controller.match.bids.isEmpty,
            teamScore: 0,
            opponentScore: 0,
          ),
        );
      } else {
        await tester.pump(const Duration(milliseconds: 600));
      }
    }

    // Play out exactly one trick, letting bots act on their own timers and
    // playing the human's single card in that trick as soon as it's due.
    while (controller.match.completedTricks.isEmpty) {
      if (controller.isHumanPlayTurn) {
        controller.playHumanCard(controller.legalHumanCards.first);
      } else {
        await tester.pump(const Duration(milliseconds: 800));
      }
    }

    // The instant the trick completes, all 4 plays must still be visible —
    // this is the exact frame the reported bug skipped.
    expect(controller.visibleTrick, isNotNull);
    expect(controller.visibleTrick!.plays, hasLength(4));

    // Nobody should be able to act during the sweep pause.
    expect(controller.isHumanPlayTurn, isFalse);

    // Only once the sweep delay elapses does the trick actually clear.
    await tester.pump(const Duration(milliseconds: 950));
    expect(controller.visibleTrick!.plays.length, lessThan(4));

    controller.dispose();
  });
}
