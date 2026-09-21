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
    this.maxSpreadAngle = 0.5,
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
    final angleStep = count > 1 ? (maxSpreadAngle * 2) / (count - 1) : 0.0;
    final overlap = cardWidth * 0.62;
    final totalWidth = cardWidth + overlap * (count - 1);

    return SizedBox(
      width: totalWidth + cardWidth,
      height: cardHeight + 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          for (var i = 0; i < count; i++) _buildCard(i, angleStep, overlap),
        ],
      ),
    );
  }

  Widget _buildCard(int index, double angleStep, double overlap) {
    final count = cards.length;
    final angle = count > 1 ? -maxSpreadAngle + angleStep * index : 0.0;
    final card = cards[index];
    final isLegal = legalCards == null || legalCards!.contains(card);

    final lift = math.cos(angle) * 10 - 10;

    return Positioned(
      left: overlap * index,
      bottom: -lift,
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
