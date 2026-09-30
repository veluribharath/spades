import 'dart:async';
import 'dart:math';

import '../ai/bot_bidder.dart';
import '../ai/bot_card_player.dart';
import '../engine/bidding_rules.dart';
import '../engine/match_state.dart';
import '../engine/trick_resolver.dart';
import '../models/bid.dart';
import '../models/card.dart';
import '../models/match_config.dart';
import '../models/seat.dart';
import '../models/trick.dart';
import 'table_view.dart';

/// Who sits in a seat when the match starts.
class SessionPlayer {
  const SessionPlayer.human(this.name) : isBot = false;
  const SessionPlayer.bot(this.name) : isBot = true;

  final String name;
  final bool isBot;
}

/// Pacing for bot turns and the pause on a finished trick.
class SessionTiming {
  const SessionTiming({
    this.botBid = const Duration(milliseconds: 550),
    this.botPlay = const Duration(milliseconds: 700),
    this.trickHold = const Duration(milliseconds: 900),
  });

  /// Slightly slower pacing for networked play, so every client gets to
  /// see each card land despite latency.
  const SessionTiming.networked()
    : botBid = const Duration(milliseconds: 700),
      botPlay = const Duration(milliseconds: 850),
      trickHold = const Duration(milliseconds: 1300);

  /// For tests: everything happens on the next timer tick.
  const SessionTiming.instant()
    : botBid = Duration.zero,
      botPlay = Duration.zero,
      trickHold = Duration.zero;

  final Duration botBid;
  final Duration botPlay;
  final Duration trickHold;
}

/// A player tried something the table won't allow (not their turn, an
/// illegal card, an over-cap bid...). The message is safe to show them.
class SessionException implements Exception {
  SessionException(this.message);
  final String message;

  @override
  String toString() => 'SessionException: $message';
}

/// The authoritative table for one match: owns the [MatchState] (and so
/// every hand), runs bot turns on timers, holds each completed trick on
/// the table for a beat, and waits for every human to be ready before
/// dealing the next hand.
///
/// Used in-process for single-player and by the room server for
/// multiplayer, so both modes share one set of rules and timings.
/// Clients only ever see [viewFor] their own seat.
class GameSession {
  GameSession({
    required Map<Seat, SessionPlayer> players,
    MatchConfig config = const MatchConfig(),
    Random? random,
    Seat? firstDealer,
    this.timing = const SessionTiming(),
    this.onChanged,
  }) : players = Map.unmodifiable(players),
       match = MatchState(
         config: config,
         random: random,
         firstDealer: firstDealer,
         finalSaySeats: _finalSaySeats(players),
       ) {
    if (!Seat.values.every(players.containsKey)) {
      throw ArgumentError('Every seat needs a player');
    }
    _schedule();
  }

  /// A human whose partner is a bot gets the final say on their team's
  /// bid (docs/RULES.md §3); two human partners bid in normal order.
  static Set<Seat> _finalSaySeats(Map<Seat, SessionPlayer> players) => {
    for (final e in players.entries)
      if (!e.value.isBot && (players[e.key.partner]?.isBot ?? false)) e.key,
  };

  final Map<Seat, SessionPlayer> players;
  final MatchState match;
  final SessionTiming timing;

  /// Called after every state change (bids, cards, trick clears, deals,
  /// connection changes).
  void Function()? onChanged;

  final Set<Seat> _disconnected = {};
  final Set<Seat> _autopilot = {};
  final Set<Seat> _ready = {};

  /// The just-completed trick, shown until the hold timer fires. Nobody
  /// may act while it's set.
  Trick? _heldTrick;
  Timer? _turnTimer;
  Timer? _holdTimer;
  bool _disposed = false;

  bool isBotControlled(Seat seat) =>
      players[seat]!.isBot || _autopilot.contains(seat);

  /// The seat whose bid or card the table is waiting for, if any.
  Seat? get toAct {
    if (_heldTrick != null) return null;
    return switch (match.phase) {
      HandPhase.bidding => match.nextBidder,
      HandPhase.playing => match.currentTrick!.nextToPlay,
      HandPhase.complete => null,
    };
  }

  /// Humans (not on autopilot, still connected) who haven't confirmed
  /// the next hand yet.
  Set<Seat> get awaitingReady {
    if (match.phase != HandPhase.complete ||
        _heldTrick != null ||
        match.status == MatchStatus.finished) {
      return const {};
    }
    return {
      for (final seat in Seat.values)
        if (!isBotControlled(seat) &&
            !_disconnected.contains(seat) &&
            !_ready.contains(seat))
          seat,
    };
  }

  void bid(Seat seat, Bid bid) => _op(() {
    _checkTurn(seat, HandPhase.bidding);
    try {
      match.submitBid(bid);
    } on IllegalBidException catch (e) {
      throw SessionException(e.message);
    }
    _changed();
    _schedule();
  });

  void play(Seat seat, PlayingCard card) => _op(() {
    _checkTurn(seat, HandPhase.playing);
    if (!match.legalPlaysFor(seat).contains(card)) {
      throw SessionException("You can't play $card right now.");
    }
    _playCard(seat, card);
  });

  /// [seat] is ready for the next hand; deals it once nobody is pending.
  void ready(Seat seat) => _op(() {
    if (_disposed) return;
    if (match.phase != HandPhase.complete || _heldTrick != null) {
      throw SessionException('The hand is still in progress.');
    }
    if (match.status == MatchStatus.finished) {
      throw SessionException('The match is over.');
    }
    _ready.add(seat);
    _changed();
    _maybeDealNext();
  });

  /// Marks a human's connection up or down (shown to the other players;
  /// a disconnected player never holds up the next deal).
  void setConnected(Seat seat, bool connected) => _op(() {
    if (_disposed) return;
    final changed = connected
        ? _disconnected.remove(seat)
        : _disconnected.add(seat);
    if (!changed) return;
    _changed();
    _maybeDealNext();
  });

  /// Lets a bot play for a human who has dropped out (or hands control
  /// back when they return).
  void setAutopilot(Seat seat, bool on) => _op(() {
    if (_disposed || players[seat]!.isBot) return;
    final changed = on ? _autopilot.add(seat) : _autopilot.remove(seat);
    if (!changed) return;
    _changed();
    _schedule();
    _maybeDealNext();
  });

  TableView viewFor(Seat seat) {
    final held = _heldTrick;
    final trick = held ?? match.currentTrick;
    final plays = trick?.plays ?? const <MapEntry<Seat, PlayingCard>>[];
    final acting = toAct;
    final myPlayTurn = acting == seat && match.phase == HandPhase.playing;

    return TableView(
      seat: seat,
      config: match.config,
      roundNumber: match.roundNumber,
      handSize: match.handSize,
      dealer: match.dealer,
      // Keep showing the table (not the hand summary) while the final
      // trick of a hand is still on display.
      phase: held != null && match.phase == HandPhase.complete
          ? HandPhase.playing
          : match.phase,
      status: match.status,
      winner: match.winner,
      teamScores: Map.unmodifiable(match.teamScores),
      teamBags: Map.unmodifiable(match.teamBags),
      seats: [
        for (final s in Seat.values)
          SeatInfo(
            seat: s,
            name: players[s]!.name,
            isBot: players[s]!.isBot,
            connected: !_disconnected.contains(s),
            autopilot: _autopilot.contains(s),
            cardCount: match.hands[s]!.length,
            bid: match.bids[s],
            tricksWon: match.tricksWonThisHand[s] ?? 0,
          ),
      ],
      hand: List.unmodifiable(match.hands[seat]!),
      trickPlays: List.unmodifiable(plays),
      trickWinner: plays.isEmpty ? null : currentWinner(trick!),
      trickHeld: held != null,
      toAct: acting,
      legalCards: myPlayTurn
          ? Set.unmodifiable(match.legalPlaysFor(seat))
          : const {},
      maxBid: match.phase == HandPhase.bidding ? match.maxBidFor(seat) : 0,
      isFirstBid: match.bids.isEmpty,
      history: [
        for (final hand in match.handHistory)
          {
            for (final e in hand.entries)
              e.key: HandLine(
                bid: e.value.teamBid,
                won: e.value.teamTricksWon,
                delta: e.value.totalDelta,
              ),
          },
      ],
      awaitingReady: awaitingReady,
    );
  }

  void dispose() {
    _disposed = true;
    _turnTimer?.cancel();
    _holdTimer?.cancel();
    onChanged = null;
  }

  // -- internals -----------------------------------------------------------

  void _checkTurn(Seat seat, HandPhase phase) {
    if (_disposed) throw SessionException('This game has ended.');
    if (match.phase != phase || toAct != seat) {
      throw SessionException("It isn't your turn.");
    }
    if (isBotControlled(seat)) {
      throw SessionException('A bot is playing this seat.');
    }
  }

  /// Nesting depth of [_op]; while > 0, [_changed] only marks the table
  /// dirty so one action produces exactly one [onChanged].
  int _opDepth = 0;
  bool _dirty = false;

  void _op(void Function() action) {
    _opDepth++;
    try {
      action();
    } finally {
      _opDepth--;
      if (_opDepth == 0 && _dirty) {
        _dirty = false;
        onChanged?.call();
      }
    }
  }

  void _changed() {
    if (_opDepth > 0) {
      _dirty = true;
    } else {
      onChanged?.call();
    }
  }

  void _schedule() {
    _turnTimer?.cancel();
    if (_disposed) return;
    final seat = toAct;
    if (seat == null || !isBotControlled(seat)) return;
    if (match.phase == HandPhase.bidding) {
      _turnTimer = Timer(timing.botBid, _runBotBid);
    } else if (match.phase == HandPhase.playing) {
      _turnTimer = Timer(timing.botPlay, _runBotPlay);
    }
  }

  void _runBotBid() => _op(() {
    if (_disposed || match.phase != HandPhase.bidding) return;
    final seat = match.nextBidder;
    if (!isBotControlled(seat)) return;
    final choice = chooseBotBid(
      hand: match.hands[seat]!,
      config: match.config,
      isFirstBidOfHand: match.bids.isEmpty,
      teamScore: match.teamScores[seat.team]!,
      opponentScore: match.teamScores[seat.team.opponent]!,
      maxBid: match.maxBidFor(seat),
    );
    try {
      match.submitBid(choice);
    } on IllegalBidException {
      // Never let a bot's misjudgment stall (or, on a server, crash) the
      // table: a plain 0 is always legal.
      match.submitBid(Bid.regular(0));
    }
    _changed();
    _schedule();
  });

  void _runBotPlay() => _op(() {
    if (_disposed || match.phase != HandPhase.playing) return;
    final trick = match.currentTrick!;
    final seat = trick.nextToPlay;
    if (!isBotControlled(seat)) return;
    final choice = chooseBotCard(
      seat: seat,
      hand: match.hands[seat]!,
      trick: trick,
      spadesBroken: match.spadesBroken,
    );
    final legal = match.legalPlaysFor(seat);
    _playCard(seat, legal.contains(choice) ? choice : legal.first);
  });

  void _playCard(Seat seat, PlayingCard card) {
    final trick = match.currentTrick!;
    match.playCard(seat, card);

    if (trick.isComplete) {
      // MatchState has already moved on (new trick or hand over); keep
      // the finished trick on the table so every card gets seen.
      _heldTrick = trick;
      _holdTimer?.cancel();
      _holdTimer = Timer(
        timing.trickHold,
        () => _op(() {
          if (_disposed) return;
          _heldTrick = null;
          if (match.phase == HandPhase.complete) _ready.clear();
          _changed();
          _schedule();
          _maybeDealNext();
        }),
      );
    }
    _changed();
    _schedule();
  }

  void _maybeDealNext() {
    if (_disposed ||
        _heldTrick != null ||
        match.phase != HandPhase.complete ||
        match.status == MatchStatus.finished) {
      return;
    }
    // A table of bots only (everyone dropped) waits for someone to come
    // back rather than racing through the match.
    final anyHumanPresent = Seat.values.any(
      (s) => !isBotControlled(s) && !_disconnected.contains(s),
    );
    if (!anyHumanPresent || awaitingReady.isNotEmpty) return;
    _ready.clear();
    match.startNextHand();
    _changed();
    _schedule();
  }
}
