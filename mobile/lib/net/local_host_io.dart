import 'dart:io';

import 'package:spades_engine/io_server.dart';

import 'local_host.dart';

const canHost = true;

Future<LocalHost> startLocalHost(int port) async {
  SpadesServer server;
  try {
    server = await SpadesServer.bind(
      address: InternetAddress.anyIPv4,
      port: port,
    );
  } on SocketException {
    // Something else already uses the usual port; take any free one.
    server = await SpadesServer.bind(address: InternetAddress.anyIPv4, port: 0);
  }
  return _IoLocalHost(server, await localNetworkAddresses());
}

class _IoLocalHost implements LocalHost {
  _IoLocalHost(this._server, this.addresses);

  final SpadesServer _server;

  @override
  final List<String> addresses;

  @override
  int get port => _server.port;

  Future<void>? _stopping;

  @override
  Future<void> stop() =>
      _stopping ??= _server.close(reason: 'The host closed the room.');
}
