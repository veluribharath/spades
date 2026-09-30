import 'dart:convert';

import '../models/bid.dart';
import '../models/card.dart';
import '../models/seat.dart';
import '../session/codec.dart';
import '../session/table_view.dart';

/// Bumped whenever a message shape changes incompatibly; the server
/// refuses clients speaking another version.
const kProtocolVersion = 1;

/// Longest message the server will parse (a snapshot is a few KB; client
/// messages are tiny).
const kMaxClientMessageBytes = 4096;

const kMaxNameLength = 20;

String _type(Map<String, Object?> m) => readString(m, 'type');

Map<String, Object?> _decodeObject(String raw) {
  final Object? json;
  try {
    json = jsonDecode(raw);
  } on FormatException {
    throw DecodeException('Not JSON');
  }
  return asMap(json, 'message');
}

// -- client → server -------------------------------------------------------

sealed class ClientMessage {
  const ClientMessage();

  Map<String, Object?> toJson();

  /// [seq] lets a client match this action to the [RoomSnapshot.ack]
  /// that confirms the server has processed it.
  String encode({int? seq}) =>
      jsonEncode({...toJson(), if (seq != null) 'seq': seq});

  static ClientMessage decode(String raw) => decodeWithSeq(raw).$1;

  /// Decodes a client message and its optional sequence number.
  static (ClientMessage, int?) decodeWithSeq(String raw) {
    final m = _decodeObject(raw);
    final seq = m['seq'];
    if (seq != null && seq is! int) throw DecodeException('Bad seq');
    return (_decodeBody(m), seq as int?);
  }

  static ClientMessage _decodeBody(Map<String, Object?> m) {
    return switch (_type(m)) {
      'create' => CreateRoom(
        name: readString(m, 'name'),
        clientId: readString(m, 'clientId'),
        version: readInt(m, 'v'),
      ),
      'join' => JoinRoom(
        code: readString(m, 'code'),
        name: readString(m, 'name'),
        clientId: readString(m, 'clientId'),
        version: readInt(m, 'v'),
      ),
      'sit' => Sit(decodeSeat(m['seat'])),
      'setBot' => SetBot(decodeSeat(m['seat']), bot: readBool(m, 'bot')),
      'start' => const StartGame(),
      'bid' => PlaceBid(decodeBid(m['bid'])),
      'play' => PlayCard(decodeCard(m['card'])),
      'ready' => const ReadyForNextHand(),
      'leave' => const LeaveRoom(),
      final other => throw DecodeException('Unknown message type: $other'),
    };
  }
}

class CreateRoom extends ClientMessage {
  const CreateRoom({
    required this.name,
    required this.clientId,
    this.version = kProtocolVersion,
  });
  final String name;
  final String clientId;
  final int version;

  @override
  Map<String, Object?> toJson() => {
    'type': 'create',
    'v': version,
    'name': name,
    'clientId': clientId,
  };
}

class JoinRoom extends ClientMessage {
  const JoinRoom({
    required this.code,
    required this.name,
    required this.clientId,
    this.version = kProtocolVersion,
  });
  final String code;
  final String name;
  final String clientId;
  final int version;

  @override
  Map<String, Object?> toJson() => {
    'type': 'join',
    'v': version,
    'code': code,
    'name': name,
    'clientId': clientId,
  };
}

/// Move to another seat (lobby only).
class Sit extends ClientMessage {
  const Sit(this.seat);
  final Seat seat;

  @override
  Map<String, Object?> toJson() => {'type': 'sit', 'seat': seat.name};
}

/// Host only, lobby only: put a bot in an empty seat or remove one.
class SetBot extends ClientMessage {
  const SetBot(this.seat, {required this.bot});
  final Seat seat;
  final bool bot;

  @override
  Map<String, Object?> toJson() => {
    'type': 'setBot',
    'seat': seat.name,
    'bot': bot,
  };
}

class StartGame extends ClientMessage {
  const StartGame();

  @override
  Map<String, Object?> toJson() => {'type': 'start'};
}

class PlaceBid extends ClientMessage {
  const PlaceBid(this.bid);
  final Bid bid;

  @override
  Map<String, Object?> toJson() => {'type': 'bid', 'bid': encodeBid(bid)};
}

class PlayCard extends ClientMessage {
  const PlayCard(this.card);
  final PlayingCard card;

  @override
  Map<String, Object?> toJson() => {'type': 'play', 'card': encodeCard(card)};
}

class ReadyForNextHand extends ClientMessage {
  const ReadyForNextHand();

  @override
  Map<String, Object?> toJson() => {'type': 'ready'};
}

class LeaveRoom extends ClientMessage {
  const LeaveRoom();

  @override
  Map<String, Object?> toJson() => {'type': 'leave'};
}

// -- server → client -------------------------------------------------------

sealed class ServerMessage {
  const ServerMessage();

  Map<String, Object?> toJson();

  String encode() => jsonEncode(toJson());

  static ServerMessage decode(String raw) {
    final m = _decodeObject(raw);
    return switch (_type(m)) {
      'room' => RoomSnapshot.fromJson(m),
      'error' => ErrorMessage(
        readString(m, 'message'),
        fatal: m['fatal'] == true,
      ),
      final other => throw DecodeException('Unknown message type: $other'),
    };
  }
}

/// Who's in one seat of a room.
class LobbySeat {
  const LobbySeat({
    required this.seat,
    this.name,
    this.isBot = false,
    this.connected = false,
    this.isHost = false,
    this.isYou = false,
  });

  final Seat seat;

  /// Null when the seat is empty.
  final String? name;
  final bool isBot;
  final bool connected;
  final bool isHost;
  final bool isYou;

  bool get isEmpty => name == null;

  Map<String, Object?> toJson() => {
    'seat': seat.name,
    'name': name,
    'isBot': isBot,
    'connected': connected,
    'isHost': isHost,
    'isYou': isYou,
  };

  factory LobbySeat.fromJson(Object? json) {
    final m = asMap(json, 'lobby seat');
    final name = m['name'];
    if (name != null && name is! String) throw DecodeException('Bad name');
    return LobbySeat(
      seat: decodeSeat(m['seat']),
      name: name as String?,
      isBot: readBool(m, 'isBot'),
      connected: readBool(m, 'connected'),
      isHost: readBool(m, 'isHost'),
      isYou: readBool(m, 'isYou'),
    );
  }
}

/// Everything a client needs, sent in full after every change: the room,
/// its seats, and (once the game is on) this client's [TableView].
class RoomSnapshot extends ServerMessage {
  const RoomSnapshot({
    required this.code,
    required this.youAreHost,
    required this.started,
    required this.seats,
    this.view,
    this.ack = 0,
  });

  final String code;

  /// The highest `seq` the server had processed from this client when it
  /// sent this snapshot. A client that just acted should wait for an ack
  /// of that action before acting again, or it may act on a stale view.
  final int ack;
  final bool youAreHost;
  final bool started;

  /// Indexed by [Seat.index].
  final List<LobbySeat> seats;
  final TableView? view;

  Seat? get yourSeat => seats.where((s) => s.isYou).firstOrNull?.seat;

  @override
  Map<String, Object?> toJson() => {
    'type': 'room',
    'code': code,
    'youAreHost': youAreHost,
    'started': started,
    'seats': [for (final s in seats) s.toJson()],
    'view': view?.toJson(),
    'ack': ack,
  };

  factory RoomSnapshot.fromJson(Map<String, Object?> m) {
    final seats = [
      for (final s in asList(m['seats'], 'seats')) LobbySeat.fromJson(s),
    ];
    if (seats.length != Seat.values.length ||
        seats.indexed.any((e) => e.$2.seat.index != e.$1)) {
      throw DecodeException('Seats must list all four seats in order');
    }
    return RoomSnapshot(
      code: readString(m, 'code'),
      youAreHost: readBool(m, 'youAreHost'),
      started: readBool(m, 'started'),
      seats: seats,
      view: m['view'] == null ? null : TableView.fromJson(m['view']),
      ack: m['ack'] is int ? m['ack'] as int : 0,
    );
  }
}

/// Something went wrong for this client. [fatal] means the client is no
/// longer in a room (e.g. the code doesn't exist) and should go back.
class ErrorMessage extends ServerMessage {
  const ErrorMessage(this.message, {this.fatal = false});
  final String message;
  final bool fatal;

  @override
  Map<String, Object?> toJson() => {
    'type': 'error',
    'message': message,
    'fatal': fatal,
  };
}
