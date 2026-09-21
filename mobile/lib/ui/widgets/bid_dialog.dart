import 'package:flutter/material.dart';

import '../../core/models/bid.dart';
import '../../core/models/match_config.dart';
import '../theme/app_theme.dart';

/// Inline bidding panel for the human player, per docs/RULES.md §3.
///
/// Rendered as an overlay above the trick area (not a modal bottom sheet)
/// so the player's own hand stays visible at the bottom of the screen
/// the whole time they're deciding a bid.
class BidPanel extends StatelessWidget {
  const BidPanel({
    super.key,
    required this.config,
    required this.maxBid,
    required this.isFirstBidOfHand,
    required this.blindNilEligible,
    required this.onBid,
  });

  final MatchConfig config;

  /// The most tricks a bid can claim — the number of cards dealt this
  /// hand (always 13 outside Progressive Spades; see docs/RULES.md §7).
  final int maxBid;
  final bool isFirstBidOfHand;
  final bool blindNilEligible;
  final ValueChanged<Bid> onBid;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Make your bid',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.gold),
          ),
          const SizedBox(height: 4),
          Text(
            maxBid == 13
                ? 'Check your hand below before you bid.'
                : 'You have $maxBid card${maxBid == 1 ? '' : 's'} this hand '
                      '— check below before you bid.',
            style: const TextStyle(color: AppColors.cream, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // A plain 0 bid is only offered when Nil is off — otherwise
              // "Nil" below is the (bonus-carrying) way to bid zero tricks.
              for (var i = config.nilEnabled ? 1 : 0; i <= maxBid; i++)
                _BidChip(label: '$i', onTap: () => onBid(Bid.regular(i))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (config.nilEnabled)
                Expanded(
                  child: _BidChip(
                    label: 'Nil',
                    accent: true,
                    onTap: () => onBid(Bid.nil()),
                  ),
                ),
              if (config.nilEnabled && config.blindNilEnabled)
                const SizedBox(width: 10),
              if (config.blindNilEnabled)
                Expanded(
                  child: _BidChip(
                    label: 'Blind Nil',
                    accent: true,
                    enabled: isFirstBidOfHand && blindNilEligible,
                    onTap: () => onBid(Bid.blindNil()),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BidChip extends StatefulWidget {
  const _BidChip({
    required this.label,
    required this.onTap,
    this.accent = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool accent;
  final bool enabled;

  @override
  State<_BidChip> createState() => _BidChipState();
}

class _BidChipState extends State<_BidChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.accent ? AppColors.gold : AppColors.feltLight;
    final hoverColor = widget.accent
        ? Color.lerp(AppColors.gold, Colors.white, 0.15)!
        : AppColors.feltLight.withValues(alpha: 0.7);
    final active = widget.enabled && _hovering;

    return Opacity(
      opacity: widget.enabled ? 1 : 0.4,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedScale(
          scale: active ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.45),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: Material(
              color: active ? hoverColor : baseColor,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: widget.enabled ? widget.onTap : null,
                borderRadius: BorderRadius.circular(14),
                hoverColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: widget.accent
                          ? AppColors.spadeInk
                          : AppColors.cream,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
