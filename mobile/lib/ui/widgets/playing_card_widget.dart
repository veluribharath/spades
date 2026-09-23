import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/card.dart';
import '../theme/app_theme.dart';
import 'suit_glyph.dart';

/// Standard card aspect ratio (poker-card proportions).
const double kCardAspectRatio = 2.5 / 3.5;

/// One playing card as crisp vector art — no bitmap assets, so it stays
/// pixel-perfect at any size (see docs/PLAN.md §2).
///
/// Faces follow the design language: ivory stock, a Cormorant rank index
/// in the corners and a single large pip in the middle. States:
/// [highlighted] (playable now: lifted with a brass ring), [dimmed] (not
/// playable: 36% opacity) and [winning] (currently taking the trick).
class PlayingCardWidget extends StatelessWidget {
  const PlayingCardWidget({
    super.key,
    required this.card,
    this.faceUp = true,
    this.width = 72,
    this.highlighted = false,
    this.dimmed = false,
    this.winning = false,
  });

  final PlayingCard? card;
  final bool faceUp;
  final double width;
  final bool highlighted;
  final bool dimmed;
  final bool winning;

  @override
  Widget build(BuildContext context) {
    final height = width / kCardAspectRatio;
    final radius = BorderRadius.circular(width * 0.12);
    final ringed = highlighted || winning;
    final small = width < 48;

    return AnimatedOpacity(
      duration: AppMotion.quick,
      opacity: dimmed ? 0.36 : 1.0,
      child: AnimatedContainer(
        duration: AppMotion.quick,
        curve: Curves.easeOut,
        width: width,
        height: height,
        transform: Matrix4.translationValues(0, highlighted ? -14 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            if (ringed)
              const BoxShadow(color: AppColors.brass, spreadRadius: 2),
            BoxShadow(
              color: Colors.black.withValues(alpha: highlighted ? 0.48 : 0.4),
              blurRadius: small ? 8 : (highlighted ? 28 : 18),
              offset: Offset(0, small ? 3 : (highlighted ? 16 : 8)),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: faceUp && card != null
              ? _CardFace(card: card!, width: width)
              : _CardBack(width: width),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.card, required this.width});

  final PlayingCard card;
  final double width;

  @override
  Widget build(BuildContext context) {
    final color = card.suit.isRed ? AppColors.garnet : AppColors.ink;
    final corner = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          card.rank.label,
          textScaler: TextScaler.noScaling,
          style: AppText.display(
            size: width * 0.31,
            weight: FontWeight.w700,
            color: color,
            height: 0.95,
          ),
        ),
        SizedBox(height: width * 0.02),
        SuitGlyph(suit: card.suit, size: width * 0.19, color: color),
      ],
    );

    return ColoredBox(
      color: AppColors.ivory,
      child: Stack(
        children: [
          Positioned(left: width * 0.09, top: width * 0.07, child: corner),
          Positioned(
            right: width * 0.09,
            bottom: width * 0.07,
            child: Transform.rotate(angle: math.pi, child: corner),
          ),
          Center(
            child: SuitGlyph(suit: card.suit, size: width * 0.46, color: color),
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final inset = width * 0.08;
    return ColoredBox(
      color: AppColors.feltRaised,
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width * 0.06),
            border: Border.all(
              color: AppColors.brass.withValues(alpha: 0.45),
              width: math.max(0.75, width * 0.015),
            ),
          ),
          child: Center(
            child: SpadeMonogram(
              size: width * 0.52,
              ringWidth: math.max(0.6, width * 0.012),
            ),
          ),
        ),
      ),
    );
  }
}
