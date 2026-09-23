import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/card.dart';
import 'playing_card_widget.dart';

/// Lays a hand of cards out in a gentle arc, fanned like a hand physically
/// held — used for both the human player's face-up hand (tappable) and
/// bots' face-down hands (decorative only).
class HandFan extends StatelessWidget {
  const HandFan({
    super.key,
    required this.cards,
    this.faceUp = true,
    this.cardWidth = 72,
    this.legalCards,
    this.onCardTap,
    this.maxSpreadAngle = 0.35,
  });

  final List<PlayingCard> cards;
  final bool faceUp;
  final double cardWidth;
  final Set<PlayingCard>? legalCards;
  final ValueChanged<PlayingCard>? onCardTap;
  final double maxSpreadAngle;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    final cardHeight = cardWidth / kCardAspectRatio;
    final count = cards.length;
    // Small hands fan gently; the arc opens up as the hand grows.
    final spread = math.min(maxSpreadAngle, 0.04 * (count - 1));
    final angleStep = count > 1 ? (spread * 2) / (count - 1) : 0.0;
    final overlap = cardWidth * (count <= 5 ? 0.72 : 0.6);
    final totalWidth = cardWidth + overlap * (count - 1);

    return SizedBox(
      width: totalWidth,
      height: cardHeight + 36,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          for (var i = 0; i < count; i++)
            _buildCard(i, spread, angleStep, overlap),
        ],
      ),
    );
  }

  Widget _buildCard(
    int index,
    double spread,
    double angleStep,
    double overlap,
  ) {
    final count = cards.length;
    final angle = count > 1 ? -spread + angleStep * index : 0.0;
    final card = cards[index];
    final isLegal = legalCards == null || legalCards!.contains(card);

    // Outer cards drop along the arc, as if held in one hand.
    final drop = (1 - math.cos(angle)) * cardWidth * 4;

    return Positioned(
      left: overlap * index,
      bottom: 14 - drop,
      child: Transform.rotate(
        angle: angle,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: (faceUp && isLegal && onCardTap != null)
              ? () => onCardTap!(card)
              : null,
          child: PlayingCardWidget(
            card: card,
            faceUp: faceUp,
            width: cardWidth,
            highlighted: faceUp && isLegal && legalCards != null,
            dimmed: faceUp && legalCards != null && !isLegal,
          ),
        ),
      ),
    );
  }
}
