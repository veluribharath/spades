import 'dart:io';

import 'package:spades_engine/io_server.dart';

/// Standalone Spades multiplayer server.
///
///     dart run bin/server.dart [--port 8080] [--host 0.0.0.0]
///
/// The port can also come from the PORT environment variable (most
/// hosting platforms set it).
Future<void> main(List<String> args) async {
  String? option(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(
      'Usage: server [--port <port>] [--host <address>]\n'
      'Serves Spades rooms over WebSockets at ws://<host>:<port>/',
    );
    return;
  }

  final port =
      int.tryParse(option('port') ?? Platform.environment['PORT'] ?? '') ??
      8080;
  final host = option('host') ?? '0.0.0.0';

  void log(String message) =>
      stdout.writeln('${DateTime.now().toIso8601String()} $message');

  final server = await SpadesServer.bind(address: host, port: port, log: log);
  log('Spades server listening on ws://$host:${server.port}/');
  for (final address in await localNetworkAddresses()) {
    log('  on this network: $address:${server.port}');
  }

  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    try {
      signal.watch().listen((_) async {
        log('shutting down');
        await server.close();
        exit(0);
      });
    } on SignalException {
      // SIGTERM can't be watched on Windows.
    }
  }
}
