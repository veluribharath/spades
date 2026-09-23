import 'package:flutter/material.dart';

import '../../core/models/bid.dart';
import '../../core/models/match_config.dart';
import '../theme/app_theme.dart';

/// Inline bidding panel for the human player, per docs/RULES.md §3.
///
/// Rendered as an overlay above the trick area (not a modal bottom sheet)
/// so the player's own hand stays visible at the bottom of the screen
/// the whole time they're deciding a bid.
class BidPanel extends StatefulWidget {
  const BidPanel({
    super.key,
    required this.config,
    required this.handSize,
    required this.maxBid,
    this.partnerBid,
    required this.isFirstBidOfHand,
    required this.blindNilEligible,
    required this.onBid,
  });

  final MatchConfig config;

  /// Cards dealt to each player this hand (always 13 outside Progressive
  /// Spades; see docs/RULES.md §7).
  final int handSize;

  /// The most tricks this bid can claim: [handSize] minus whatever the
  /// partner already bid, since a partnership can't bid more tricks than
  /// the hand contains.
  final int maxBid;

  /// The partner's bid, if they've already bid this hand.
  final Bid? partnerBid;
  final bool isFirstBidOfHand;
  final bool blindNilEligible;
  final ValueChanged<Bid> onBid;

  @override
  State<BidPanel> createState() => _BidPanelState();
}

class _BidPanelState extends State<BidPanel> {
  /// The chip under the pointer, previewed in the team total.
  int? _preview;

  @override
  Widget build(BuildContext context) {
    final partner = widget.partnerBid;
    final cards = widget.handSize;
    final cardsLabel = '$cards card${cards == 1 ? '' : 's'}';

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.felt.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.brass.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 48,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your bid', style: AppText.display(size: 30)),
          const SizedBox(height: 8),
          Text.rich(
            partner == null
                ? TextSpan(
                    text:
                        'You hold $cardsLabel. Bid the tricks you expect '
                        'to take — check your hand below.',
                  )
                : TextSpan(
                    children: [
                      const TextSpan(text: 'North bid '),
                      TextSpan(
                        text: '$partner',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text:
                            '. You set the team total — up to $cards '
                            'trick${cards == 1 ? '' : 's'} this hand.',
                      ),
                    ],
                  ),
            style: AppText.ui(size: 14, color: AppColors.sage, height: 1.5),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // A plain 0 bid is only offered when Nil is off — otherwise
              // "Nil" below is the (bonus-carrying) way to bid zero tricks.
              for (var i = widget.config.nilEnabled ? 1 : 0; i <= cards; i++)
                _BidChip(
                  label: '$i',
                  enabled: i <= widget.maxBid,
                  onHover: (hovering) =>
                      setState(() => _preview = hovering ? i : null),
                  onTap: () => widget.onBid(Bid.regular(i)),
                ),
            ],
          ),
          if (widget.config.nilEnabled || widget.config.blindNilEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.config.nilEnabled)
                  Expanded(
                    child: _NilButton(
                      label: 'Nil',
                      onTap: () => widget.onBid(Bid.nil()),
                    ),
                  ),
                if (widget.config.nilEnabled && widget.config.blindNilEnabled)
                  const SizedBox(width: 10),
                if (widget.config.blindNilEnabled)
                  Expanded(
                    child: _NilButton(
                      label: 'Blind Nil',
                      onTap: widget.isFirstBidOfHand && widget.blindNilEligible
                          ? () => widget.onBid(Bid.blindNil())
                          : null,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TEAM TOTAL', style: AppText.label()),
              Text(
                _teamTotal(partner),
                style: AppText.display(size: 26, color: AppColors.brass),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _teamTotal(Bid? partner) {
    final preview = _preview;
    if (partner == null) return preview == null ? '—' : '$preview';
    final p = partner.teamTricks;
    return preview == null ? '$p + ?' : '$p + $preview = ${p + preview}';
  }
}

/// A number chip: raised felt at rest, brass hairline and halo on hover,
/// a faint dashed-looking ghost when the bid would exceed the hand.
class _BidChip extends StatefulWidget {
  const _BidChip({
    required this.label,
    required this.onTap,
    required this.onHover,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;
  final bool enabled;

  @override
  State<_BidChip> createState() => _BidChipState();
}

class _BidChipState extends State<_BidChip> {
  bool _hovering = false;

  void _setHover(bool value) {
    if (!widget.enabled || _hovering == value) return;
    setState(() => _hovering = value);
    widget.onHover(value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final active = enabled && _hovering;
    final radius = BorderRadius.circular(14);

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTap: enabled ? widget.onTap : null,
        onTapDown: enabled ? (_) => _setHover(true) : null,
        onTapCancel: () => _setHover(false),
        child: AnimatedContainer(
          duration: AppMotion.quick,
          curve: Curves.easeOut,
          width: 48,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: !enabled
                ? Colors.transparent
                : active
                ? AppColors.feltHover
                : AppColors.feltRaised,
            borderRadius: radius,
            border: Border.all(
              color: active
                  ? AppColors.brass
                  : enabled
                  ? const Color(0x24ECE4D2)
                  : AppColors.hairline,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brass.withValues(alpha: active ? 0.14 : 0),
                spreadRadius: 4,
              ),
            ],
          ),
          child: Text(
            widget.label,
            textScaler: TextScaler.noScaling,
            style: AppText.display(
              size: 24,
              color: !enabled
                  ? AppColors.text.withValues(alpha: 0.3)
                  : active
                  ? AppColors.ivory
                  : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _NilButton extends StatelessWidget {
  const _NilButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brass,
        side: BorderSide(
          color: AppColors.brass.withValues(alpha: onTap == null ? 0.25 : 0.7),
        ),
      ),
      child: Text(label),
    );
  }
}
