import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ai/bot_bidder.dart';
import '../core/ai/bot_card_player.dart';
import '../core/engine/match_state.dart';
import '../core/models/bid.dart';
import '../core/models/card.dart';
import '../core/models/match_config.dart';
import '../core/models/seat.dart';
import '../core/models/trick.dart';

/// The human always sits South; the other three seats are bots. This is
/// the only human/bot assignment for v1 — see docs/PLAN.md milestone 7
/// for pass-and-play / online-multiplayer as future extensions.
const kHumanSeat = Seat.south;

/// How long a completed trick stays fully visible before the table
/// clears it for the next one. Without this, [MatchState.playCard]
/// resolves and replaces the trick synchronously, so the 4th card (and
/// the completed trick as a whole) would never get its own rendered
/// frame.
const _trickSweepDelay = Duration(milliseconds: 900);

/// Owns a [MatchState] and drives bot turns automatically, exposing a
/// small action surface for the UI. Kept out of `core/` because it deals
/// in Flutter's [ChangeNotifier] + timing concerns, not game rules.
class GameController extends ChangeNotifier {
  GameController({MatchConfig config = const MatchConfig(), Random? random})
    : match = MatchState(
        config: config,
        random: random,
        finalSaySeat: kHumanSeat,
      ) {
    _scheduleBotsIfNeeded();
  }

  MatchState match;
  Timer? _botTimer;
  Timer? _trickSweepTimer;

  /// The just-completed trick, held on screen until [_trickSweepTimer]
  /// fires. While this is set, play is paused for both the human and
  /// bots so nobody can jump ahead before the 4th card has been seen.
  Trick? _justCompletedTrick;

  /// What the table should render as the current trick.
  Trick? get visibleTrick => _justCompletedTrick ?? match.currentTrick;

  bool get isHumanBidTurn =>
      match.phase == HandPhase.bidding && match.nextBidder == kHumanSeat;

  bool get isHumanPlayTurn =>
      _justCompletedTrick == null &&
      match.phase == HandPhase.playing &&
      match.currentTrick!.nextToPlay == kHumanSeat;

  Set<PlayingCard> get legalHumanCards =>
      isHumanPlayTurn ? match.legalPlaysFor(kHumanSeat).toSet() : const {};

  void submitHumanBid(Bid bid) {
    if (!isHumanBidTurn) return;
    match.submitBid(bid);
    notifyListeners();
    _scheduleBotsIfNeeded();
  }

  void playHumanCard(PlayingCard card) {
    if (!isHumanPlayTurn) return;
    if (!legalHumanCards.contains(card)) return;
    _playCard(kHumanSeat, card);
  }

  void startNextHand() {
    if (match.phase != HandPhase.complete) return;
    if (match.status != MatchStatus.ongoing &&
        match.status != MatchStatus.suddenDeath) {
      return;
    }
    match.startNextHand();
    notifyListeners();
    _scheduleBotsIfNeeded();
  }

  void _scheduleBotsIfNeeded() {
    _botTimer?.cancel();
    if (_justCompletedTrick != null) return;
    if (match.phase == HandPhase.bidding && match.nextBidder != kHumanSeat) {
      _botTimer = Timer(const Duration(milliseconds: 550), _runBotBid);
    } else if (match.phase == HandPhase.playing &&
        match.currentTrick!.nextToPlay != kHumanSeat) {
      _botTimer = Timer(const Duration(milliseconds: 700), _runBotPlay);
    }
  }

  void _runBotBid() {
    final seat = match.nextBidder;
    final bid = chooseBotBid(
      hand: match.hands[seat]!,
      config: match.config,
      isFirstBidOfHand: match.bids.isEmpty,
      teamScore: match.teamScores[seat.team]!,
      opponentScore: match.teamScores[seat.team.opponent]!,
      maxBid: match.maxBidFor(seat),
    );
    match.submitBid(bid);
    notifyListeners();
    _scheduleBotsIfNeeded();
  }

  void _runBotPlay() {
    final trick = match.currentTrick!;
    final seat = trick.nextToPlay;
    final card = chooseBotCard(
      seat: seat,
      hand: match.hands[seat]!,
      trick: trick,
      spadesBroken: match.spadesBroken,
    );
    _playCard(seat, card);
  }

  void _playCard(Seat seat, PlayingCard card) {
    final trick = match.currentTrick!;
    match.playCard(seat, card);
    notifyListeners();

    if (trick.isComplete) {
      // Hold the finished trick on screen instead of racing straight to
      // whatever MatchState already advanced to (a fresh empty trick, or
      // hand-complete).
      _justCompletedTrick = trick;
      _trickSweepTimer?.cancel();
      _trickSweepTimer = Timer(_trickSweepDelay, () {
        _justCompletedTrick = null;
        notifyListeners();
        _scheduleBotsIfNeeded();
      });
    } else {
      _scheduleBotsIfNeeded();
    }
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _trickSweepTimer?.cancel();
    super.dispose();
  }
}

/// The app currently launches straight into Progressive Spades (hand
/// size 1→13, per docs/RULES.md §7) — there's no mode-select screen yet
/// (see docs/PLAN.md milestone 7 for a future Classic/variant toggle).
final gameControllerProvider =
    ChangeNotifierProvider.autoDispose<GameController>((ref) {
      return GameController(config: const MatchConfig.progressive());
    });
