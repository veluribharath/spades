import '../models/bid.dart';
import '../models/match_config.dart';

/// Thrown when a proposed [Bid] violates the active [MatchConfig].
class IllegalBidException implements Exception {
  IllegalBidException(this.message);
  final String message;

  @override
  String toString() => 'IllegalBidException: $message';
}

/// Validates a bid against the match's rule configuration, per
/// docs/RULES.md §3. Throws [IllegalBidException] if illegal.
void validateBid(
  Bid bid, {
  required MatchConfig config,
  required bool isFirstBidOfHand,
  required int biddingTeamScore,
  required int opposingTeamScore,
  required int handSize,
  int partnerTricks = 0,
}) {
  if (bid.tricks > handSize) {
    throw IllegalBidException(
      'Cannot bid more than the $handSize card(s) dealt this hand.',
    );
  }
  if (bid.tricks + partnerTricks > handSize) {
    throw IllegalBidException(
      'Your partnership cannot bid more than the $handSize trick(s) '
      'in this hand (partner already bid $partnerTricks).',
    );
  }

  if (bid.isNil && !config.nilEnabled) {
    throw IllegalBidException('Nil bids are disabled in this match.');
  }

  if (bid.isBlind) {
    if (!config.blindNilEnabled) {
      throw IllegalBidException('Blind Nil is disabled in this match.');
    }
    if (!isFirstBidOfHand) {
      throw IllegalBidException(
        'Blind Nil may only be bid as the first bid of the hand.',
      );
    }
    if (opposingTeamScore - biddingTeamScore < 100) {
      throw IllegalBidException(
        'Blind Nil requires being at least 100 points behind.',
      );
    }
  }
}
