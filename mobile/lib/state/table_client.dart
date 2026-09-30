import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:spades_engine/multiplayer.dart';
import 'package:spades_engine/spades_engine.dart';

enum ConnectionStatus { connecting, connected, reconnecting, closed }

/// What the table screen talks to: the current [view] of the table for
/// this player, and the few actions they can take. Implemented
/// in-process for single-player ([LocalTableClient]) and over a
/// WebSocket for multiplayer (RemoteTableClient).
abstract class TableClient extends ChangeNotifier {
  TableView? get view;

  ConnectionStatus get status;

  bool get isMultiplayer;

  /// A one-off problem to show the player (e.g. a rejected action);
  /// cleared by [takeError].
  String? get error;

  /// Returns [error] and clears it, so it's shown once.
  String? takeError();

  void bid(Bid bid);
  void play(PlayingCard card);

  /// Confirms this player is ready for the next hand.
  void nextHand();

  /// Leaves the table for good.
  void leave();
}

/// Single-player: you at South, three bots, all in-process.
class LocalTableClient extends TableClient {
  LocalTableClient({
    MatchConfig config = const MatchConfig.progressive(),
    Random? random,
    Seat? firstDealer,
    SessionTiming timing = const SessionTiming(),
  }) {
    _session = GameSession(
      players: const {
        Seat.south: SessionPlayer.human('You'),
        Seat.west: SessionPlayer.bot('West'),
        Seat.north: SessionPlayer.bot('North'),
        Seat.east: SessionPlayer.bot('East'),
      },
      config: config,
      random: random,
      firstDealer: firstDealer,
      timing: timing,
      onChanged: _changed,
    );
  }

  static const seat = Seat.south;

  late final GameSession _session;
  TableView? _view;
  String? _error;
  bool _disposed = false;

  /// The session behind this table (for tests).
  @visibleForTesting
  GameSession get session => _session;

  @override
  TableView get view => _view ??= _session.viewFor(seat);

  @override
  ConnectionStatus get status => ConnectionStatus.connected;

  @override
  bool get isMultiplayer => false;

  @override
  String? get error => _error;

  @override
  String? takeError() {
    final e = _error;
    _error = null;
    return e;
  }

  void _changed() {
    _view = null;
    if (!_disposed) notifyListeners();
  }

  void _guard(void Function() action) {
    if (_disposed) return;
    try {
      action();
    } on SessionException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  @override
  void bid(Bid bid) => _guard(() => _session.bid(seat, bid));

  @override
  void play(PlayingCard card) => _guard(() => _session.play(seat, card));

  @override
  void nextHand() => _guard(() => _session.ready(seat));

  @override
  void leave() => _session.dispose();

  @override
  void dispose() {
    _disposed = true;
    _session.dispose();
    super.dispose();
  }
}
