import '../engine/match_state.dart';
import '../models/bid.dart';
import '../models/card.dart';
import '../models/match_config.dart';
import '../models/seat.dart';
import 'codec.dart';

/// What one seat at the table is allowed to know about another: public
/// facts only (never the cards themselves).
class SeatInfo {
  const SeatInfo({
    required this.seat,
    required this.name,
    required this.isBot,
    required this.connected,
    required this.autopilot,
    required this.cardCount,
    required this.bid,
    required this.tricksWon,
  });

  final Seat seat;
  final String name;
  final bool isBot;

  /// False while a human player's connection is down.
  final bool connected;

  /// True while a bot is playing for a human who dropped out.
  final bool autopilot;
  final int cardCount;
  final Bid? bid;
  final int tricksWon;

  Map<String, Object?> toJson() => {
    'seat': seat.name,
    'name': name,
    'isBot': isBot,
    'connected': connected,
    'autopilot': autopilot,
    'cardCount': cardCount,
    'bid': bid == null ? null : encodeBid(bid!),
    'tricksWon': tricksWon,
  };

  factory SeatInfo.fromJson(Object? json) {
    final m = asMap(json, 'seat info');
    return SeatInfo(
      seat: decodeSeat(m['seat']),
      name: readString(m, 'name'),
      isBot: readBool(m, 'isBot'),
      connected: readBool(m, 'connected'),
      autopilot: readBool(m, 'autopilot'),
      cardCount: readInt(m, 'cardCount'),
      bid: m['bid'] == null ? null : decodeBid(m['bid']),
      tricksWon: readInt(m, 'tricksWon'),
    );
  }
}

/// One team's line in the score history.
class HandLine {
  const HandLine({required this.bid, required this.won, required this.delta});

  final int bid;
  final int won;
  final int delta;

  Map<String, Object?> toJson() => {'bid': bid, 'won': won, 'delta': delta};

  factory HandLine.fromJson(Object? json) {
    final m = asMap(json, 'hand line');
    return HandLine(
      bid: readInt(m, 'bid'),
      won: readInt(m, 'won'),
      delta: readInt(m, 'delta'),
    );
  }
}

/// Everything one seat needs to draw the table, and nothing it mustn't
/// see: its own hand, but only card *counts* for everyone else.
///
/// Seats here are absolute; the UI rotates them so [seat] is drawn at
/// the bottom.
class TableView {
  const TableView({
    required this.seat,
    required this.config,
    required this.roundNumber,
    required this.handSize,
    required this.dealer,
    required this.phase,
    required this.status,
    required this.winner,
    required this.teamScores,
    required this.teamBags,
    required this.seats,
    required this.hand,
    required this.trickPlays,
    required this.trickWinner,
    required this.trickHeld,
    required this.toAct,
    required this.legalCards,
    required this.maxBid,
    required this.isFirstBid,
    required this.history,
    required this.awaitingReady,
  });

  /// The seat this view was made for.
  final Seat seat;
  final MatchConfig config;
  final int roundNumber;
  final int handSize;
  final Seat dealer;

  /// Stays [HandPhase.playing] while a hand's final trick is still being
  /// shown, so the summary never covers the last card.
  final HandPhase phase;
  final MatchStatus status;
  final Team? winner;
  final Map<Team, int> teamScores;
  final Map<Team, int> teamBags;

  /// Indexed by [Seat.index].
  final List<SeatInfo> seats;

  /// This seat's own cards.
  final List<PlayingCard> hand;

  /// The trick on the table, in play order (a just-completed trick while
  /// [trickHeld]).
  final List<MapEntry<Seat, PlayingCard>> trickPlays;
  final Seat? trickWinner;
  final bool trickHeld;

  /// Whose bid or card the table is waiting on; null while a completed
  /// trick is held and between hands.
  final Seat? toAct;

  /// This seat's legal cards when it's their turn to play, else empty.
  final Set<PlayingCard> legalCards;

  /// The highest bid this seat may make right now.
  final int maxBid;
  final bool isFirstBid;

  /// One entry per finished hand.
  final List<Map<Team, HandLine>> history;

  /// Humans who still need to tap "Next hand".
  final Set<Seat> awaitingReady;

  SeatInfo info(Seat s) => seats[s.index];

  bool get isMyBidTurn => phase == HandPhase.bidding && toAct == seat;
  bool get isMyPlayTurn => phase == HandPhase.playing && toAct == seat;
  bool get iAmReady => !awaitingReady.contains(seat);
  bool get matchOver => status == MatchStatus.finished;

  Map<String, Object?> toJson() => {
    'seat': seat.name,
    'config': encodeConfig(config),
    'roundNumber': roundNumber,
    'handSize': handSize,
    'dealer': dealer.name,
    'phase': phase.name,
    'status': status.name,
    'winner': winner?.name,
    'teamScores': {for (final e in teamScores.entries) e.key.name: e.value},
    'teamBags': {for (final e in teamBags.entries) e.key.name: e.value},
    'seats': [for (final s in seats) s.toJson()],
    'hand': [for (final c in hand) encodeCard(c)],
    'trick': [
      for (final p in trickPlays) [p.key.name, encodeCard(p.value)],
    ],
    'trickWinner': trickWinner?.name,
    'trickHeld': trickHeld,
    'toAct': toAct?.name,
    'legal': [for (final c in legalCards) encodeCard(c)],
    'maxBid': maxBid,
    'isFirstBid': isFirstBid,
    'history': [
      for (final h in history)
        {for (final e in h.entries) e.key.name: e.value.toJson()},
    ],
    'awaitingReady': [for (final s in awaitingReady) s.name],
  };

  factory TableView.fromJson(Object? json) {
    final m = asMap(json, 'view');
    Map<Team, int> teamInts(String key) {
      final t = asMap(m[key], key);
      return {for (final team in Team.values) team: readInt(t, team.name)};
    }

    final seats = [
      for (final s in asList(m['seats'], 'seats')) SeatInfo.fromJson(s),
    ];
    if (seats.length != Seat.values.length ||
        seats.indexed.any((e) => e.$2.seat.index != e.$1)) {
      throw DecodeException('Seats must list all four seats in order');
    }

    return TableView(
      seat: decodeSeat(m['seat']),
      config: decodeConfig(m['config']),
      roundNumber: readInt(m, 'roundNumber'),
      handSize: readInt(m, 'handSize'),
      dealer: decodeSeat(m['dealer']),
      phase: decodeEnumValue(HandPhase.values, m['phase'], 'phase'),
      status: decodeEnumValue(MatchStatus.values, m['status'], 'status'),
      winner: m['winner'] == null ? null : decodeTeam(m['winner']),
      teamScores: teamInts('teamScores'),
      teamBags: teamInts('teamBags'),
      seats: seats,
      hand: [for (final c in asList(m['hand'], 'hand')) decodeCard(c)],
      trickPlays: [
        for (final p in asList(m['trick'], 'trick'))
          () {
            final pair = asList(p, 'trick play');
            if (pair.length != 2) throw DecodeException('Bad trick play');
            return MapEntry(decodeSeat(pair[0]), decodeCard(pair[1]));
          }(),
      ],
      trickWinner: m['trickWinner'] == null
          ? null
          : decodeSeat(m['trickWinner']),
      trickHeld: readBool(m, 'trickHeld'),
      toAct: m['toAct'] == null ? null : decodeSeat(m['toAct']),
      legalCards: {for (final c in asList(m['legal'], 'legal')) decodeCard(c)},
      maxBid: readInt(m, 'maxBid'),
      isFirstBid: readBool(m, 'isFirstBid'),
      history: [
        for (final h in asList(m['history'], 'history'))
          () {
            final line = asMap(h, 'history entry');
            return {
              for (final team in Team.values)
                team: HandLine.fromJson(line[team.name]),
            };
          }(),
      ],
      awaitingReady: {
        for (final s in asList(m['awaitingReady'], 'awaitingReady'))
          decodeSeat(s),
      },
    );
  }
}
