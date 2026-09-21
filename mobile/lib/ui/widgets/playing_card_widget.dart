import 'package:flutter/material.dart';

import '../../core/models/card.dart';
import '../../core/models/suit.dart';
import '../theme/app_theme.dart';

/// Standard card aspect ratio (poker-card proportions).
const double kCardAspectRatio = 2.5 / 3.5;

/// Renders one playing card as crisp vector art — no bitmap assets, so it
/// stays pixel-perfect at any size and carries no licensing risk (see
/// docs/PLAN.md §2). Draws either the face (rank/suit pips) or a
/// patterned back, and reacts to [highlighted] (legal-to-play) and
/// [dimmed] (illegal-right-now) states.
class PlayingCardWidget extends StatelessWidget {
  const PlayingCardWidget({
    super.key,
    required this.card,
    this.faceUp = true,
    this.width = 72,
    this.highlighted = false,
    this.dimmed = false,
  });

  final PlayingCard? card;
  final bool faceUp;
  final double width;
  final bool highlighted;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final height = width / kCardAspectRatio;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: dimmed ? 0.45 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.11),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: highlighted ? 0.45 : 0.3),
              blurRadius: highlighted ? 14 : 6,
              offset: Offset(0, highlighted ? 8 : 3),
            ),
            if (highlighted)
              BoxShadow(
                color: AppColors.seatHighlight.withValues(alpha: 0.8),
                blurRadius: 0,
                spreadRadius: 2,
              ),
          ],
        ),
        transform: highlighted
            ? (Matrix4.identity()..translateByDouble(0.0, -10.0, 0.0, 1.0))
            : Matrix4.identity(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(width * 0.11),
          child: CustomPaint(
            size: Size(width, height),
            painter: faceUp && card != null
                ? _CardFacePainter(card!)
                : const _CardBackPainter(),
          ),
        ),
      ),
    );
  }
}

class _CardFacePainter extends CustomPainter {
  const _CardFacePainter(this.card);
  final PlayingCard card;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.11),
    );
    canvas.drawRRect(rrect, Paint()..color = AppColors.cream);
    canvas.drawRRect(
      rrect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.black.withValues(alpha: 0.12),
    );

    final color = card.suit.isRed ? AppColors.heartRed : AppColors.spadeInk;
    final cornerStyle = TextStyle(
      color: color,
      fontWeight: FontWeight.w800,
      fontSize: size.width * 0.24,
      height: 1.0,
    );

    void paintCorner(Offset offset, {bool flip = false}) {
      final span = TextSpan(
        children: [
          TextSpan(text: '${card.rank.label}\n', style: cornerStyle),
          TextSpan(
            text: card.suit.symbol,
            style: cornerStyle.copyWith(fontSize: size.width * 0.2),
          ),
        ],
      );
      final tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      if (flip) canvas.rotate(3.14159265);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    paintCorner(Offset(size.width * 0.17, size.height * 0.15));
    paintCorner(Offset(size.width * 0.83, size.height * 0.85), flip: true);

    final centerSpan = TextSpan(
      text: card.suit.symbol,
      style: TextStyle(
        color: color.withValues(alpha: 0.9),
        fontSize: size.width * 0.52,
        fontWeight: FontWeight.w700,
      ),
    );
    final centerPainter = TextPainter(
      text: centerSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    centerPainter.paint(
      canvas,
      Offset(
        (size.width - centerPainter.width) / 2,
        (size.height - centerPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _CardFacePainter oldDelegate) =>
      oldDelegate.card != card;
}

class _CardBackPainter extends CustomPainter {
  const _CardBackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.11),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.feltLight, AppColors.feltDark],
        ).createShader(Offset.zero & size),
    );

    final border = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(size.width * 0.08),
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(
      border,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.03
        ..color = AppColors.gold.withValues(alpha: 0.85),
    );

    final spadeStyle = TextStyle(
      color: AppColors.gold.withValues(alpha: 0.9),
      fontSize: size.width * 0.34,
    );
    final tp = TextPainter(
      text: TextSpan(text: Suit.spades.symbol, style: spadeStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CardBackPainter oldDelegate) => false;
}
