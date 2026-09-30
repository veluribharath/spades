import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spades_app/net/local_host.dart';
import 'package:spades_app/state/remote_table_client.dart';
import 'package:spades_app/state/table_client.dart';
import 'package:spades_engine/spades_engine.dart';

Future<void> _until(RemoteTableClient c, bool Function() ok) async {
  final done = Completer<void>();
  void check() {
    if (!done.isCompleted && ok()) done.complete();
  }

  c.addListener(check);
  check();
  try {
    await done.future.timeout(const Duration(seconds: 15));
  } finally {
    c.removeListener(check);
  }
}

/// Hosting on this device, over real sockets: the embedded server, the
/// WebSocket client, create → join → start, then the host closing.
void main() {
  test('host on this device, a friend joins, the host closes', () async {
    expect(canHostOnThisDevice, isTrue);
    final host = await startLocalHost(port: 0);
    final uri = Uri.parse('ws://127.0.0.1:${host.port}/');

    final alice = RemoteTableClient(
      server: uri,
      name: 'Alice',
      clientId: 'alice-localhost',
    );
    await _until(alice, () => alice.room != null);
    final bob = RemoteTableClient(
      server: uri,
      name: 'Bob',
      clientId: 'bob-localhost',
      roomCode: alice.code,
    );
    await _until(bob, () => bob.room?.yourSeat == Seat.north);

    alice.start();
    await _until(bob, () => bob.view != null);
    expect(bob.view!.info(Seat.south).name, 'Alice');

    await host.stop();
    await _until(bob, () => bob.status == ConnectionStatus.closed);
    expect(bob.fatalError, 'The host closed the room.');
    alice.dispose();
    bob.dispose();
  });
}
