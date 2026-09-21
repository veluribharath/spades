import 'package:flutter/material.dart';

import '../../core/models/bid.dart';
import '../../core/models/match_config.dart';
import '../theme/app_theme.dart';

/// Bottom sheet for the human player to submit a bid, per docs/RULES.md §3.
Future<Bid?> showBidSheet(
  BuildContext context, {
  required MatchConfig config,
  required bool isFirstBidOfHand,
  required bool blindNilEligible,
}) {
  return showModalBottomSheet<Bid>(
    context: context,
    backgroundColor: AppColors.feltMid,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _BidSheetContent(
      config: config,
      isFirstBidOfHand: isFirstBidOfHand,
      blindNilEligible: blindNilEligible,
    ),
  );
}

class _BidSheetContent extends StatelessWidget {
  const _BidSheetContent({
    required this.config,
    required this.isFirstBidOfHand,
    required this.blindNilEligible,
  });

  final MatchConfig config;
  final bool isFirstBidOfHand;
  final bool blindNilEligible;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Make your bid',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 1; i <= 13; i++)
                  _BidChip(
                    label: '$i',
                    onTap: () => Navigator.pop(context, Bid.regular(i)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (config.nilEnabled)
                  Expanded(
                    child: _BidChip(
                      label: 'Nil',
                      accent: true,
                      onTap: () => Navigator.pop(context, Bid.nil()),
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
                      onTap: () => Navigator.pop(context, Bid.blindNil()),
                    ),
                  ),
              ],
            ),
          ],
        ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
