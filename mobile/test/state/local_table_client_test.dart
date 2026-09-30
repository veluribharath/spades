import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spades_app/state/table_client.dart';
import 'package:spades_engine/spades_engine.dart';

/// Regression: the 4th card of a trick must stay on the table for a beat
/// (the engine resolves a trick synchronously), and nobody may act while
/// it does.
void main() {
  testWidgets('a completed trick stays visible before the table clears it', (
    tester,
  ) async {
    final client = LocalTableClient(
      config: const MatchConfig(),
      random: Random(7),
    );
    final session = client.session;

    while (session.match.phase == HandPhase.bidding) {
      if (client.view.isMyBidTurn) {
        client.bid(
          chooseBotBid(
            hand: client.view.hand,
            config: client.view.config,
            isFirstBidOfHand: client.view.isFirstBid,
            teamScore: 0,
            opponentScore: 0,
            maxBid: client.view.maxBid,
          ),
        );
      } else {
        await tester.pump(const Duration(milliseconds: 600));
      }
    }

    while (session.match.completedTricks.isEmpty) {
      if (client.view.isMyPlayTurn) {
        client.play(client.view.legalCards.first);
      } else {
        await tester.pump(const Duration(milliseconds: 800));
      }
    }

    expect(client.view.trickPlays, hasLength(4));
    expect(client.view.trickHeld, isTrue);
    expect(client.view.isMyPlayTurn, isFalse);

    await tester.pump(const Duration(milliseconds: 950));
    expect(client.view.trickPlays.length, lessThan(4));

    client.dispose();
  });

  test('a rejected action surfaces once as an error', () {
    final client = LocalTableClient(random: Random(1), firstDealer: Seat.west);
    // Dealer West → North bids first, so it's not our turn.
    client.bid(Bid.regular(0));
    expect(client.takeError(), "It isn't your turn.");
    expect(client.takeError(), isNull);
    client.dispose();
  });
}
