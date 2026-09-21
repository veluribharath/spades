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
    required this.isFirstBidOfHand,
    required this.blindNilEligible,
    required this.onBid,
  });

  final MatchConfig config;
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
          const Text(
            'Check your hand below before you bid.',
            style: TextStyle(color: AppColors.cream, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 1; i <= 13; i++)
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

class _BidChip extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: accent ? AppColors.gold : AppColors.feltLight,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: accent ? AppColors.spadeInk : AppColors.cream,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
