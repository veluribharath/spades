/// Serves a [RoomHub] over WebSockets using dart:io. Used by the
/// standalone server (bin/server.dart) and by the app when a phone hosts
/// a game on the local network. Not available in the browser build.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'multiplayer.dart';

export 'multiplayer.dart';

/// A running WebSocket server for a [RoomHub].
///
/// - `GET /` with a WebSocket upgrade → a game connection.
/// - `GET /health` → `ok` (for load balancers / uptime checks).
class SpadesServer {
  SpadesServer._(this._http, this.hub, this._log, this._trustProxy);

  final HttpServer _http;
  final RoomHub hub;
  final void Function(String)? _log;

  /// Take the client address from `X-Forwarded-For` (only safe behind a
  /// reverse proxy that sets it).
  final bool _trustProxy;
  final Set<WebSocket> _sockets = {};

  int get port => _http.port;

  /// How often idle sockets are pinged, so a phone that vanished without
  /// closing its connection is noticed (and its seat handed to a bot).
  static const pingInterval = Duration(seconds: 10);

  static Future<SpadesServer> bind({
    Object? address,
    int port = 8080,
    RoomHub? hub,
    void Function(String message)? log,
    bool trustProxy = false,
  }) async {
    final http = await HttpServer.bind(
      address ?? InternetAddress.anyIPv4,
      port,
    );
    final server = SpadesServer._(http, hub ?? RoomHub(), log, trustProxy);
    http.listen(server._handle, onError: (Object e) => log?.call('http: $e'));
    return server;
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (request.uri.path == '/health') {
        request.response
          ..headers.contentType = ContentType.text
          ..write('ok ${hub.roomCount} rooms');
        await request.response.close();
        return;
      }
      if (request.uri.path != '/' ||
          !WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      final forwarded = _trustProxy
          ? request.headers.value('x-forwarded-for')?.split(',').first.trim()
          : null;
      final remote =
          (forwarded != null && forwarded.isNotEmpty ? forwarded : null) ??
          request.connectionInfo?.remoteAddress.address;
      final socket = await WebSocketTransformer.upgrade(request);
      _serve(socket, remote);
    } catch (e) {
      _log?.call('request failed: $e');
    }
  }

  void _serve(WebSocket socket, String? remote) {
    socket.pingInterval = pingInterval;
    _sockets.add(socket);
    final peer = hub.connect(_SocketConnection(socket), remoteAddress: remote);
    _log?.call('connected ${remote ?? '?'} (${_sockets.length} open)');
    var gone = false;
    void cleanUp() {
      if (gone) return;
      gone = true;
      _sockets.remove(socket);
      peer.closed();
      _log?.call('disconnected ${remote ?? '?'} (${_sockets.length} open)');
    }

    socket.listen(
      (data) {
        if (data is String) {
          peer.receive(data);
        } else if (data is List<int>) {
          // Tolerate clients that send text frames as bytes.
          peer.receive(utf8.decode(data, allowMalformed: true));
        }
      },
      onDone: cleanUp,
      // A reset connection surfaces as an error, not always a clean close;
      // either way the hub must learn the player is gone.
      onError: (Object e) {
        _log?.call('socket error: $e');
        cleanUp();
        unawaited(socket.close());
      },
      cancelOnError: true,
    );
  }

  /// Stops serving. Players still connected are told [reason].
  Future<void> close({String reason = 'The game server shut down.'}) async {
    hub.dispose(reason: reason);
    // In parallel, and bounded: a vanished phone won't answer the close
    // handshake.
    await Future.wait([
      for (final s in _sockets.toList())
        s
            .close(WebSocketStatus.goingAway)
            .timeout(const Duration(seconds: 2), onTimeout: () => null),
    ]);
    await _http.close(force: true);
  }
}

class _SocketConnection implements PeerConnection {
  _SocketConnection(this._socket);
  final WebSocket _socket;

  @override
  void send(String message) {
    if (_socket.readyState == WebSocket.open) _socket.add(message);
  }

  @override
  void close() {
    unawaited(_socket.close(WebSocketStatus.normalClosure));
  }
}

/// This machine's non-loopback IPv4 addresses — what other devices on
/// the same network use to reach a hosted game.
Future<List<String>> localNetworkAddresses() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    // Cellular / VPN interfaces can't be reached from the Wi-Fi, even
    // when they have private-looking addresses.
    final cellularOrVpn = RegExp(
      r'^(rmnet|ccmni|pdp_ip|wwan|tun|utun|ppp|ipsec|clat|v4-)',
      caseSensitive: false,
    );
    final ranked = <(int, String)>[];
    for (final i in interfaces) {
      for (final a in i.addresses) {
        if (a.isLoopback || a.isLinkLocal) continue;
        ranked.add((cellularOrVpn.hasMatch(i.name) ? 1 : 0, a.address));
      }
    }
    ranked.sort((a, b) => a.$1.compareTo(b.$1));
    final addresses = [for (final r in ranked) r.$2];
    return addresses;
  } catch (_) {
    return const [];
  }
}
