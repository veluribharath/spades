import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/models/card.dart';
import '../../core/models/seat.dart';
import 'playing_card_widget.dart';

/// The center-table area showing cards played to the current trick,
/// positioned near the seat that played them.
class TrickArea extends StatelessWidget {
  const TrickArea({super.key, required this.plays, this.cardWidth = 64});

  final Map<Seat, PlayingCard> plays;
  final double cardWidth;

  Alignment _alignmentFor(Seat seat) => switch (seat) {
    Seat.south => const Alignment(0, 0.55),
    Seat.north => const Alignment(0, -0.55),
    Seat.west => const Alignment(-0.55, 0),
    Seat.east => const Alignment(0.55, 0),
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cardWidth * 4,
      height: cardWidth * 4 / kCardAspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final entry in plays.entries)
            Align(
              alignment: _alignmentFor(entry.key),
              child: PlayingCardWidget(card: entry.value, width: cardWidth)
                  .animate()
                  .fadeIn(duration: 180.ms)
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    end: const Offset(1, 1),
                    duration: 180.ms,
                    curve: Curves.easeOutBack,
                  ),
            ),
        ],
      ),
    );
  }
}
