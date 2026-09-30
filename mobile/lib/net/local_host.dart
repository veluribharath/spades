import 'local_host_stub.dart' if (dart.library.io) 'local_host_io.dart' as impl;

/// A game server running on this device, so friends on the same network
/// can join without any other infrastructure.
abstract class LocalHost {
  int get port;

  /// Addresses other devices can reach this one on (best guess first).
  List<String> get addresses;

  Future<void> stop();
}

/// Whether this platform can host (not in the browser).
bool get canHostOnThisDevice => impl.canHost;

/// Starts hosting; throws if the platform can't or the port is busy.
Future<LocalHost> startLocalHost({int port = 8080}) =>
    impl.startLocalHost(port);
