import 'dart:async';

import 'package:spades_engine/multiplayer.dart';
import 'package:stream_channel/stream_channel.dart';

/// Connects RemoteTableClients straight to an in-process [RoomHub], so
/// client tests exercise the real protocol and server logic with no
/// sockets.
class InMemoryHub {
  InMemoryHub(this.hub);

  final RoomHub hub;
  final List<_Link> _links = [];

  /// When true, new connections fail (server unreachable).
  bool refuse = false;

  int get connectionCount => _links.length;

  Future<StreamChannel<dynamic>> connect(Uri uri) async {
    if (refuse) throw StateError('connection refused');
    final controller = StreamChannelController<dynamic>();
    final link = _Link(controller);
    link.peer = hub.connect(link);
    controller.foreign.stream.listen(
      (m) => link.peer.receive(m as String),
      onDone: link.dropped,
    );
    _links.add(link);
    return controller.local;
  }

  /// Simulates every connection dropping (Wi-Fi blip, server restart).
  void dropAll() {
    for (final link in _links.toList()) {
      link.close();
      link.dropped();
    }
    _links.clear();
  }
}

class _Link implements PeerConnection {
  _Link(this._controller);

  final StreamChannelController<dynamic> _controller;
  late final HubPeer peer;
  bool _closed = false;
  bool _reported = false;

  @override
  void send(String message) {
    if (!_closed) _controller.foreign.sink.add(message);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(_controller.foreign.sink.close());
  }

  void dropped() {
    _closed = true;
    if (_reported) return;
    _reported = true;
    peer.closed();
  }
}
