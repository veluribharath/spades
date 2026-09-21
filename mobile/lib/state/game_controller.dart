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

/// The human always sits South; the other three seats are bots. This is
/// the only human/bot assignment for v1 — see docs/PLAN.md milestone 7
/// for pass-and-play / online-multiplayer as future extensions.
const kHumanSeat = Seat.south;

/// Owns a [MatchState] and drives bot turns automatically, exposing a
/// small action surface for the UI. Kept out of `core/` because it deals
/// in Flutter's [ChangeNotifier] + timing concerns, not game rules.
class GameController extends ChangeNotifier {
  GameController({MatchConfig config = const MatchConfig(), Random? random})
    : match = MatchState(config: config, random: random) {
    _scheduleBotsIfNeeded();
  }

  MatchState match;
  Timer? _botTimer;

  bool get isHumanBidTurn =>
      match.phase == HandPhase.bidding && match.nextBidder == kHumanSeat;

  bool get isHumanPlayTurn =>
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
    match.playCard(kHumanSeat, card);
    notifyListeners();
    _scheduleBotsIfNeeded();
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
    match.playCard(seat, card);
    notifyListeners();
    _scheduleBotsIfNeeded();
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }
}

final gameControllerProvider =
    ChangeNotifierProvider.autoDispose<GameController>((ref) {
      return GameController();
    });
