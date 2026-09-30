import 'dart:async';
import 'dart:math';

import '../models/match_config.dart';
import '../models/seat.dart';
import '../protocol/messages.dart';
import '../session/codec.dart';
import '../session/game_session.dart';

/// One client's connection, as the hub sees it. The dart:io server wraps
/// a WebSocket in this; tests use an in-memory implementation.
abstract interface class PeerConnection {
  void send(String message);
  void close();
}

/// Hosts any number of rooms. Each room is a lobby of up to four seats
/// that turns into a [GameSession] when its host starts the game.
///
/// Transport-agnostic: call [connect] for every new connection, then feed
/// that peer's messages to [HubPeer.receive] and tell it when the
/// connection drops via [HubPeer.closed]. All game state stays here;
/// clients only ever get [RoomSnapshot]s for themselves.
class RoomHub {
  RoomHub({
    Random? random,
    this.timing = const SessionTiming.networked(),
    this.matchConfig = const MatchConfig.progressive(),
    this.reconnectGrace = const Duration(seconds: 20),
    this.idleRoomTimeout = const Duration(minutes: 10),
    this.maxRooms = 500,
  }) : _random = random ?? Random.secure();

  final Random _random;
  final SessionTiming timing;
  final MatchConfig matchConfig;

  /// How long a dropped player keeps their seat before a bot takes over
  /// (in a game) or the seat is freed (in the lobby).
  final Duration reconnectGrace;

  /// How long a room with nobody connected survives.
  final Duration idleRoomTimeout;
  final int maxRooms;

  final Map<String, _Room> _rooms = {};

  int get roomCount => _rooms.length;
  bool hasRoom(String code) => _rooms.containsKey(code);

  HubPeer connect(PeerConnection connection) => HubPeer._(this, connection);

  void dispose() {
    for (final room in _rooms.values.toList()) {
      room.close();
    }
  }

  static const _codeLetters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';

  String _newCode() {
    while (true) {
      final code = String.fromCharCodes([
        for (var i = 0; i < 4; i++)
          _codeLetters.codeUnitAt(_random.nextInt(_codeLetters.length)),
      ]);
      if (!_rooms.containsKey(code)) return code;
    }
  }
}

/// The hub's handle on one connection.
class HubPeer {
  HubPeer._(this._hub, this._connection);

  final RoomHub _hub;
  final PeerConnection _connection;
  _Room? _room;
  _Member? _member;

  /// Last sequence number received on this connection (echoed back as
  /// [RoomSnapshot.ack]).
  int _lastSeq = 0;

  static final _clientIdPattern = RegExp(r'^[A-Za-z0-9_-]{8,64}$');

  void receive(String raw) {
    if (raw.length > kMaxClientMessageBytes) {
      _error('That message was too large.');
      return;
    }
    final ClientMessage message;
    final int? seq;
    try {
      (message, seq) = ClientMessage.decodeWithSeq(raw);
    } on DecodeException {
      _error("Couldn't understand that message.");
      return;
    }
    if (seq != null) _lastSeq = seq;

    switch (message) {
      case CreateRoom(:final name, :final clientId, :final version):
        if (!_checkHello(clientId, version)) return;
        _create(name, clientId);
      case JoinRoom(:final code, :final name, :final clientId, :final version):
        if (!_checkHello(clientId, version)) return;
        _join(code, name, clientId);
      case _:
        final room = _room;
        final member = _member;
        if (room == null || member == null) {
          _error('Join a room first.', fatal: true);
          return;
        }
        room.handle(member, message);
    }
  }

  /// The underlying connection is gone.
  void closed() {
    final room = _room;
    final member = _member;
    _room = null;
    _member = null;
    if (room != null && member != null) room.disconnected(member, this);
  }

  void _send(ServerMessage message) => _connection.send(message.encode());

  void _error(String message, {bool fatal = false}) =>
      _send(ErrorMessage(message, fatal: fatal));

  bool _checkHello(String clientId, int version) {
    if (version != kProtocolVersion) {
      _error(
        'This server runs a different version of Spades. Update the app '
        'on every device and try again.',
        fatal: true,
      );
      return false;
    }
    if (!_clientIdPattern.hasMatch(clientId)) {
      _error('Invalid client id.', fatal: true);
      return false;
    }
    if (_room != null) {
      _error("You're already in a room.");
      return false;
    }
    return true;
  }

  void _create(String name, String clientId) {
    if (_hub._rooms.length >= _hub.maxRooms) {
      _error('The server is full right now. Try again later.', fatal: true);
      return;
    }
    final room = _Room(_hub, _hub._newCode());
    _hub._rooms[room.code] = room;
    final member = room.addMember(clientId, _sanitizeName(name));
    member.seat = Seat.south;
    room.hostId = clientId;
    room.bind(member, this);
  }

  void _join(String rawCode, String name, String clientId) {
    final code = rawCode.trim().toUpperCase();
    final room = _hub._rooms[code];
    if (room == null) {
      _error('No room with code "$code".', fatal: true);
      return;
    }
    final existing = room.members[clientId];
    if (existing != null) {
      existing.name = _sanitizeName(name);
      room.bind(existing, this);
      return;
    }
    if (room.session != null) {
      _error('That game has already started.', fatal: true);
      return;
    }
    final seat = room.openSeat();
    if (seat == null) {
      _error('That room is full.', fatal: true);
      return;
    }
    final member = room.addMember(clientId, _sanitizeName(name));
    room.bots.remove(seat);
    member.seat = seat;
    room.bind(member, this);
  }

  static String _sanitizeName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'Player';
    return cleaned.length > kMaxNameLength
        ? cleaned.substring(0, kMaxNameLength).trim()
        : cleaned;
  }
}

class _Member {
  _Member(this.id, this.name);

  final String id;
  String name;
  HubPeer? peer;
  Seat? seat;
  Timer? graceTimer;

  bool get connected => peer != null;
}

String _seatName(Seat seat) =>
    '${seat.name[0].toUpperCase()}${seat.name.substring(1)}';

class _Room {
  _Room(this.hub, this.code);

  final RoomHub hub;
  final String code;
  String hostId = '';

  /// In join order (used to pick a new host).
  final Map<String, _Member> members = {};
  final Set<Seat> bots = {};
  GameSession? session;
  Timer? _idleTimer;
  bool _closed = false;

  _Member addMember(String id, String name) => members[id] = _Member(id, name);

  _Member? memberAt(Seat seat) =>
      members.values.where((m) => m.seat == seat).firstOrNull;

  /// First free seat for a newcomer, partner seat first; a bot gives its
  /// seat up to a human.
  Seat? openSeat() {
    const preference = [Seat.south, Seat.north, Seat.west, Seat.east];
    return preference
            .where((s) => memberAt(s) == null && !bots.contains(s))
            .firstOrNull ??
        preference.where((s) => memberAt(s) == null).firstOrNull;
  }

  void bind(_Member member, HubPeer peer) {
    final previous = member.peer;
    if (previous != null && previous != peer) {
      // Same player, new connection (e.g. reopened the app): the old one
      // is retired.
      previous._room = null;
      previous._member = null;
      previous._error(
        'You joined this room from another connection.',
        fatal: true,
      );
      previous._connection.close();
    }
    member.peer = peer;
    member.graceTimer?.cancel();
    member.graceTimer = null;
    peer._room = this;
    peer._member = member;
    _idleTimer?.cancel();
    _idleTimer = null;
    final seat = member.seat;
    if (session != null && seat != null) {
      session!.setAutopilot(seat, false);
      session!.setConnected(seat, true);
    }
    broadcast();
  }

  void handle(_Member member, ClientMessage message) {
    final peer = member.peer!;
    switch (message) {
      case Sit(:final seat):
        if (session != null) return peer._error('The game has started.');
        final taken = memberAt(seat);
        if (taken != null && taken != member) {
          return peer._error('That seat is taken.');
        }
        bots.remove(seat);
        member.seat = seat;
        broadcast();
      case SetBot(:final seat, :final bot):
        if (member.id != hostId) {
          return peer._error('Only the host can add or remove bots.');
        }
        if (session != null) return peer._error('The game has started.');
        if (bot) {
          if (memberAt(seat) != null) {
            return peer._error('Someone is sitting there.');
          }
          bots.add(seat);
        } else {
          bots.remove(seat);
        }
        broadcast();
      case StartGame():
        if (member.id != hostId) {
          return peer._error('Only the host can start the game.');
        }
        if (session != null) return _sendSnapshot(member);
        _start();
      case PlaceBid(:final bid):
        _play(member, (s, seat) => s.bid(seat, bid));
      case PlayCard(:final card):
        _play(member, (s, seat) => s.play(seat, card));
      case ReadyForNextHand():
        _play(member, (s, seat) => s.ready(seat));
      case LeaveRoom():
        _leave(member);
      case CreateRoom() || JoinRoom():
        peer._error("You're already in a room.");
    }
  }

  void _play(_Member member, void Function(GameSession, Seat) action) {
    final s = session;
    final seat = member.seat;
    if (s == null || seat == null) {
      return member.peer!._error("The game hasn't started yet.");
    }
    try {
      action(s, seat);
    } on SessionException catch (e) {
      member.peer!._error(e.message);
      // Resync the client in case its view was stale.
      _sendSnapshot(member);
    }
  }

  void _start() {
    final players = <Seat, SessionPlayer>{};
    for (final seat in Seat.values) {
      final member = memberAt(seat);
      if (member == null) bots.add(seat);
      players[seat] = member == null
          ? SessionPlayer.bot(_seatName(seat))
          : SessionPlayer.human(member.name);
    }
    final s = GameSession(
      players: players,
      config: hub.matchConfig,
      random: hub._random,
      timing: hub.timing,
    );
    session = s;
    for (final member in members.values) {
      if (!member.connected && member.seat != null) {
        s.setConnected(member.seat!, false);
      }
    }
    s.onChanged = broadcast;
    broadcast();
  }

  void _leave(_Member member) {
    final peer = member.peer;
    member.peer = null;
    peer?._room = null;
    peer?._member = null;
    member.graceTimer?.cancel();
    member.graceTimer = null;
    final seat = member.seat;
    if (session != null && seat != null) {
      // Seat stays theirs (they can rejoin with the code); a bot covers.
      session!.setConnected(seat, false);
      session!.setAutopilot(seat, true);
    } else {
      _remove(member);
    }
    if (_closed) return;
    broadcast();
    _checkIdle();
  }

  void disconnected(_Member member, HubPeer peer) {
    if (member.peer != peer) return;
    member.peer = null;
    final seat = member.seat;
    if (session != null && seat != null) session!.setConnected(seat, false);
    member.graceTimer?.cancel();
    member.graceTimer = Timer(hub.reconnectGrace, () {
      member.graceTimer = null;
      if (member.connected || _closed) return;
      final s = session;
      if (s != null && member.seat != null) {
        s.setAutopilot(member.seat!, true);
      } else {
        _remove(member);
        if (_closed) return;
        broadcast();
      }
    });
    broadcast();
    _checkIdle();
  }

  void _remove(_Member member) {
    members.remove(member.id);
    member.graceTimer?.cancel();
    if (members.isEmpty) {
      close();
      return;
    }
    if (hostId == member.id) {
      hostId =
          (members.values.where((m) => m.connected).firstOrNull ??
                  members.values.first)
              .id;
    }
  }

  void _checkIdle() {
    if (_closed || members.values.any((m) => m.connected)) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(hub.idleRoomTimeout, close);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _idleTimer?.cancel();
    session?.dispose();
    for (final m in members.values) {
      m.graceTimer?.cancel();
      final peer = m.peer;
      if (peer != null) {
        peer._room = null;
        peer._member = null;
      }
    }
    hub._rooms.remove(code);
  }

  void broadcast() {
    if (_closed) return;
    for (final member in members.values) {
      if (member.connected) _sendSnapshot(member);
    }
  }

  void _sendSnapshot(_Member member) {
    final s = session;
    final seat = member.seat;
    member.peer?._send(
      RoomSnapshot(
        code: code,
        youAreHost: member.id == hostId,
        started: s != null,
        seats: [for (final seat in Seat.values) _lobbySeat(seat, member)],
        view: s != null && seat != null ? s.viewFor(seat) : null,
        ack: member.peer?._lastSeq ?? 0,
      ),
    );
  }

  LobbySeat _lobbySeat(Seat seat, _Member viewer) {
    final m = memberAt(seat);
    if (m != null) {
      return LobbySeat(
        seat: seat,
        name: m.name,
        connected: m.connected,
        isHost: m.id == hostId,
        isYou: m == viewer,
      );
    }
    if (bots.contains(seat)) {
      return LobbySeat(
        seat: seat,
        name: _seatName(seat),
        isBot: true,
        connected: true,
      );
    }
    return LobbySeat(seat: seat);
  }
}
