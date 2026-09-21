import 'dart:math';

import '../models/bid.dart';
import '../models/card.dart';
import '../models/match_config.dart';
import '../models/seat.dart';
import '../models/trick.dart';
import 'bidding_rules.dart';
import 'dealer.dart';
import 'legal_plays.dart';
import 'scoring.dart';
import 'trick_resolver.dart';

enum HandPhase { bidding, playing, complete }

enum MatchStatus { ongoing, suddenDeath, finished }

/// Drives one full match of Spades hand-by-hand: dealing, bidding, trick
/// play, and scoring, per docs/RULES.md. This class is pure Dart with no
/// Flutter dependency so it can be unit-tested and driven headlessly by
/// bots or a UI layer alike.
class MatchState {
  MatchState({MatchConfig? config, Random? random, Seat? firstDealer})
    : config = config ?? const MatchConfig(),
      _random = random ?? Random(),
      dealer = firstDealer ?? Seat.values[Random().nextInt(4)] {
    _startNewHand();
  }

  final MatchConfig config;
  final Random _random;

  Seat dealer;
  HandPhase phase = HandPhase.bidding;
  MatchStatus status = MatchStatus.ongoing;

  final Map<Team, int> teamScores = {Team.southNorth: 0, Team.westEast: 0};
  final Map<Team, int> teamBags = {Team.southNorth: 0, Team.westEast: 0};
  final List<Map<Team, TeamHandScore>> handHistory = [];

  late Map<Seat, List<PlayingCard>> hands;
  final Map<Seat, Bid> bids = {};
  Trick? currentTrick;
  final List<Trick> completedTricks = [];
  bool spadesBroken = false;
  final Map<Seat, int> tricksWonThisHand = {for (final s in Seat.values) s: 0};

  Seat get firstBidder => dealer.next;

  Seat get nextBidder => Seat.values.firstWhere(
    (s) => !bids.containsKey(s),
    orElse: () {
      throw StateError('Bidding already complete');
    },
  );

  bool get biddingComplete => bids.length == Seat.values.length;

  void _startNewHand() {
    hands = dealHand(random: _random);
    bids.clear();
    currentTrick = null;
    completedTricks.clear();
    spadesBroken = false;
    tricksWonThisHand.updateAll((_, __) => 0);
    phase = HandPhase.bidding;
  }

  /// Submits [bid] for whichever seat bids next, in turn order starting
  /// left of the dealer. Validates against [config] via [validateBid].
  void submitBid(Bid bid) {
    if (phase != HandPhase.bidding) {
      throw StateError('Not currently in the bidding phase');
    }
    final seat = nextBidder;
    final isFirst = bids.isEmpty;
    validateBid(
      bid,
      config: config,
      isFirstBidOfHand: isFirst,
      biddingTeamScore: teamScores[seat.team]!,
      opposingTeamScore: teamScores[seat.team.opponent]!,
    );
    bids[seat] = bid;

    if (biddingComplete) {
      phase = HandPhase.playing;
      currentTrick = Trick(leader: firstBidder);
    }
  }

  List<PlayingCard> legalPlaysFor(Seat seat) {
    if (phase != HandPhase.playing) return const [];
    return legalPlays(
      hand: hands[seat]!,
      trick: currentTrick!,
      spadesBroken: spadesBroken,
    );
  }

  /// Plays [card] for [seat], resolving the trick and advancing to the
  /// next one (or ending the hand) once all 4 players have played.
  void playCard(Seat seat, PlayingCard card) {
    if (phase != HandPhase.playing) {
      throw StateError('Not currently in the playing phase');
    }
    final trick = currentTrick!;
    if (seat != trick.nextToPlay) {
      throw StateError('It is not $seat\'s turn to play');
    }
    final legal = legalPlaysFor(seat);
    if (!legal.contains(card)) {
      throw StateError('$card is not a legal play for $seat right now');
    }

    if (breaksSpades(card, leadSuit: trick.leadSuit)) {
      spadesBroken = true;
    } else if (trick.leadSuit == null && card.isSpade) {
      spadesBroken = true;
    }

    hands[seat]!.remove(card);
    trick.play(seat, card);

    if (trick.isComplete) {
      final winner = resolveTrick(trick);
      tricksWonThisHand[winner] = tricksWonThisHand[winner]! + 1;
      completedTricks.add(trick);

      if (completedTricks.length == 13) {
        _finishHand();
      } else {
        currentTrick = Trick(leader: winner);
      }
    }
  }

  void _finishHand() {
    phase = HandPhase.complete;
    final results = <Team, TeamHandScore>{};

    for (final team in Team.values) {
      final players = team.seats
          .map(
            (seat) => PlayerHandResult(
              seat: seat,
              bid: bids[seat]!,
              tricksWon: tricksWonThisHand[seat]!,
            ),
          )
          .toList();

      final score = computeTeamHandScore(
        team: team,
        players: players,
        bagCountBefore: teamBags[team]!,
        config: config,
      );
      results[team] = score;
      teamScores[team] = teamScores[team]! + score.totalDelta;
      teamBags[team] = score.bagCountAfter;
    }

    handHistory.add(results);
    _evaluateMatchStatus();
  }

  void _evaluateMatchStatus() {
    final losers = Team.values
        .where((t) => teamScores[t]! <= config.lossFloor)
        .toList();
    final winners = Team.values
        .where((t) => teamScores[t]! >= config.targetScore)
        .toList();

    if (losers.isNotEmpty || winners.isNotEmpty) {
      if (winners.length == 2 &&
          teamScores[winners[0]] == teamScores[winners[1]]) {
        status = MatchStatus.suddenDeath;
        return;
      }
      status = MatchStatus.finished;
    }
  }

  /// The winning team once [status] is [MatchStatus.finished].
  Team? get winner {
    if (status != MatchStatus.finished) return null;
    final losers = Team.values
        .where((t) => teamScores[t]! <= config.lossFloor)
        .toList();
    if (losers.length == 1) return losers.first.opponent;
    return teamScores[Team.southNorth]! >= teamScores[Team.westEast]!
        ? Team.southNorth
        : Team.westEast;
  }

  /// Advances to the next hand after [_finishHand]. Rotates the dealer.
  void startNextHand() {
    if (phase != HandPhase.complete) {
      throw StateError('Current hand has not finished yet');
    }
    if (status == MatchStatus.finished) {
      throw StateError('Match is already finished');
    }
    dealer = dealer.next;
    _startNewHand();
  }
}
