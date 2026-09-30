import 'dart:async';
import 'dart:math';

import 'package:spades_engine/multiplayer.dart';
import 'package:spades_engine/spades_engine.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'table_client.dart';

/// Opens a connection to a room server. Swappable so tests can connect
/// to an in-process [RoomHub] instead of a real socket.
typedef ChannelConnector = Future<StreamChannel<dynamic>> Function(Uri uri);

Future<StreamChannel<dynamic>> connectWebSocket(Uri uri) async {
  final channel = WebSocketChannel.connect(uri);
  try {
    await channel.ready.timeout(const Duration(seconds: 8));
  } catch (_) {
    unawaited(channel.sink.close());
    rethrow;
  }
  return channel;
}

/// Multiplayer: the table (and lobby) as seen through a room server.
///
/// Creates a room when [roomCode] is null, otherwise joins it. Keeps the
/// connection alive: if it drops, it retries with backoff and resumes the
/// same seat (the server recognizes [clientId]).
class RemoteTableClient extends TableClient {
  RemoteTableClient({
    required this.server,
    required this.name,
    required this.clientId,
    String? roomCode,
    ChannelConnector? connect,
    this.maxBackoff = const Duration(seconds: 8),
    this.initialAttempts = 3,
    this.giveUpAfter = const Duration(minutes: 3),
  }) : _code = roomCode?.trim().toUpperCase(),
       _connector = connect ?? connectWebSocket {
    unawaited(_connect());
  }

  final Uri server;
  final String name;
  final String clientId;
  final Duration maxBackoff;

  /// How many times to try before giving up if we never got in at all.
  final int initialAttempts;

  /// How long to keep reconnecting after losing an established game
  /// (the server holds a room for 10 minutes; a bot covers meanwhile).
  final Duration giveUpAfter;
  DateTime? _lostSince;

  final ChannelConnector _connector;
  String? _code;
  StreamChannel<dynamic>? _channel;
  StreamSubscription<dynamic>? _subscription;
  RoomSnapshot? _room;
  ConnectionStatus _status = ConnectionStatus.connecting;
  String? _error;
  String? _fatalError;
  int _seq = 0;
  int _failures = 0;
  Timer? _retryTimer;
  bool _everJoined = false;
  bool _closed = false;

  /// The latest room snapshot (lobby + table).
  RoomSnapshot? get room => _room;

  /// Room code once the server has assigned or confirmed it.
  String? get code => _room?.code ?? _code;

  /// Why the client gave up (bad code, full room, unreachable server...).
  /// Once set, [status] is [ConnectionStatus.closed] for good.
  String? get fatalError => _fatalError;

  @override
  TableView? get view => _room?.view;

  @override
  ConnectionStatus get status => _status;

  @override
  bool get isMultiplayer => true;

  @override
  String? get error => _error;

  @override
  String? takeError() {
    final e = _error;
    _error = null;
    return e;
  }

  /// True while an action we sent hasn't been confirmed yet; further
  /// actions are ignored so a double tap can't act on a stale view.
  bool get awaitingServer =>
      !_answeredByError && _room != null && _room!.ack < _seq;

  /// The server rejected our last action with an error, which answers it
  /// just as well as an ack.
  bool _answeredByError = false;

  // -- lobby ---------------------------------------------------------------

  void sit(Seat seat) => _send(Sit(seat));
  void setBot(Seat seat, {required bool bot}) => _send(SetBot(seat, bot: bot));
  void start() => _send(const StartGame());

  // -- table ---------------------------------------------------------------

  @override
  void bid(Bid bid) => _send(PlaceBid(bid));

  @override
  void play(PlayingCard card) => _send(PlayCard(card));

  @override
  void nextHand() => _send(const ReadyForNextHand());

  @override
  void leave() {
    if (_closed) return;
    if (_status == ConnectionStatus.connected) {
      _channel?.sink.add(const LeaveRoom().encode(seq: ++_seq));
    }
    _shutDown();
    notifyListeners();
  }

  @override
  void dispose() {
    _shutDown();
    super.dispose();
  }

  // -- connection ------------------------------------------------------------

  void _send(ClientMessage message) {
    if (_closed || _status != ConnectionStatus.connected || awaitingServer) {
      return;
    }
    _answeredByError = false;
    _channel!.sink.add(message.encode(seq: ++_seq));
  }

  Future<void> _connect() async {
    if (_closed) return;
    final StreamChannel<dynamic> channel;
    try {
      channel = await _connector(server);
    } catch (_) {
      _connectionLost();
      return;
    }
    if (_closed) {
      unawaited(channel.sink.close());
      return;
    }
    _channel = channel;
    // Sequence numbers are per connection on the server side too.
    _seq = 0;
    _answeredByError = false;
    _subscription = channel.stream.listen(
      _onData,
      onDone: _connectionLost,
      onError: (Object _) => _connectionLost(),
      cancelOnError: true,
    );
    final code = _code;
    channel.sink.add(
      (code == null
              ? CreateRoom(name: name, clientId: clientId)
              : JoinRoom(code: code, name: name, clientId: clientId))
          .encode(),
    );
  }

  void _onData(dynamic data) {
    if (_closed || data is! String) return;
    final ServerMessage message;
    try {
      message = ServerMessage.decode(data);
    } on DecodeException {
      return;
    }
    switch (message) {
      case RoomSnapshot():
        _room = message;
        _code = message.code;
        _everJoined = true;
        _failures = 0;
        _lostSince = null;
        _status = ConnectionStatus.connected;
      case ErrorMessage(:final message, :final fatal):
        if (fatal) {
          _fatalError = message;
          _shutDown();
        } else {
          _error = message;
          _answeredByError = true;
        }
    }
    notifyListeners();
  }

  void _connectionLost() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    if (_closed) return;
    _failures++;
    if (!_everJoined && _failures >= initialAttempts) {
      _fatalError =
          "Couldn't reach a Spades game at ${server.host}:${server.port}. "
          'Check the address and that you are on the same network.';
      _shutDown();
      notifyListeners();
      return;
    }
    final lostSince = _lostSince ??= DateTime.now();
    if (_everJoined && DateTime.now().difference(lostSince) > giveUpAfter) {
      _fatalError = 'Lost the connection to the game.';
      _shutDown();
      notifyListeners();
      return;
    }
    _status = _everJoined
        ? ConnectionStatus.reconnecting
        : ConnectionStatus.connecting;
    final delay = Duration(
      milliseconds: min(
        maxBackoff.inMilliseconds,
        500 * pow(2, _failures - 1).toInt(),
      ),
    );
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(_connect()));
    notifyListeners();
  }

  void _shutDown() {
    if (_closed) return;
    _closed = true;
    _status = ConnectionStatus.closed;
    _retryTimer?.cancel();
    _subscription?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) unawaited(channel.sink.close());
  }
}
