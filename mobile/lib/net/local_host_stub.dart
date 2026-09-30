import 'local_host.dart';

const canHost = false;

Future<LocalHost> startLocalHost(int port) =>
    throw UnsupportedError('Hosting is not available in the browser.');
