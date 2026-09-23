import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/models/card.dart';
import '../../core/models/seat.dart';
import '../theme/app_theme.dart';
import 'playing_card_widget.dart';

/// The center-table area showing cards played to the current trick,
/// positioned near the seat that played them. Each card settles at a
/// slight, seat-specific angle so the trick reads as tossed rather than
/// placed; the card currently taking the trick wears the brass ring.
class TrickArea extends StatelessWidget {
  const TrickArea({
    super.key,
    required this.plays,
    this.winner,
    this.cardWidth = 64,
  });

  final Map<Seat, PlayingCard> plays;

  /// Seat whose card is currently winning the trick, if any.
  final Seat? winner;
  final double cardWidth;

  /// Where each seat's card rests, relative to the table center: a full
  /// card height above/below for North/South and roughly a card width to
  /// either side for West/East, so no two cards overlap.
  Offset _offsetFor(Seat seat, double w, double h) => switch (seat) {
    Seat.south => Offset(0, h * 1.02),
    Seat.north => Offset(0, -h * 1.02),
    Seat.west => Offset(-w * 0.98, 0),
    Seat.east => Offset(w * 0.98, 0),
  };

  /// Settle angle in radians (N 3°, W −5°, E 4°, S −2°).
  double _tiltFor(Seat seat) => switch (seat) {
    Seat.north => 0.052,
    Seat.west => -0.087,
    Seat.east => 0.07,
    Seat.south => -0.035,
  };

  Offset _entryFor(Seat seat) => switch (seat) {
    Seat.south => const Offset(0, 0.6),
    Seat.north => const Offset(0, -0.6),
    Seat.west => const Offset(-0.6, 0),
    Seat.east => const Offset(0.6, 0),
  };

  @override
  Widget build(BuildContext context) {
    final cardHeight = cardWidth / kCardAspectRatio;
    return SizedBox(
      width: cardWidth * 3.2,
      height: cardHeight * 3.2,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          for (final entry in plays.entries)
            Transform.translate(
              offset: _offsetFor(entry.key, cardWidth, cardHeight),
              child:
                  Transform.rotate(
                        angle: _tiltFor(entry.key),
                        child: PlayingCardWidget(
                          card: entry.value,
                          width: cardWidth,
                          winning: plays.length > 1 && entry.key == winner,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: AppMotion.quick)
                      .slide(
                        begin: _entryFor(entry.key),
                        end: Offset.zero,
                        duration: AppMotion.flight,
                        curve: Curves.easeOutCubic,
                      ),
            ),
        ],
      ),
    );
  }
}
