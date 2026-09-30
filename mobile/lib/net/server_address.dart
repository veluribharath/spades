/// Port used both by the standalone server and by a phone hosting a game.
const kDefaultGamePort = 8080;

/// Turns what a player typed into a WebSocket URL, or null if it can't
/// be one.
///
/// - `192.168.1.20` → `ws://192.168.1.20:8080/`
/// - `192.168.1.20:9000` → `ws://192.168.1.20:9000/`
/// - `spades.example.com` → `ws://spades.example.com:8080/`
/// - `wss://spades.example.com` / `https://…` → `wss://spades.example.com/`
/// - `ws://…` / `http://…` → `ws://…` (port kept, else scheme default)
Uri? parseServerAddress(String input) {
  var text = input.trim();
  if (text.isEmpty || text.contains(' ')) return null;

  String scheme;
  final schemeMatch = RegExp(r'^([a-zA-Z]+)://').firstMatch(text);
  var explicitScheme = false;
  if (schemeMatch != null) {
    explicitScheme = true;
    scheme = switch (schemeMatch.group(1)!.toLowerCase()) {
      'ws' || 'http' => 'ws',
      'wss' || 'https' => 'wss',
      _ => '',
    };
    if (scheme.isEmpty) return null;
    text = text.substring(schemeMatch.end);
  } else {
    scheme = 'ws';
  }

  final Uri parsed;
  try {
    parsed = Uri.parse('$scheme://$text');
  } on FormatException {
    return null;
  }
  if (parsed.host.isEmpty) return null;

  final port = parsed.hasPort
      ? parsed.port
      : explicitScheme
      ? (scheme == 'wss' ? 443 : 80)
      : kDefaultGamePort;
  return Uri(
    scheme: scheme,
    host: parsed.host,
    port: port,
    path: parsed.path.isEmpty ? '/' : parsed.path,
  );
}

/// How to show [uri] back to a player (what they'd type to join).
String displayAddress(Uri uri) {
  final defaultPort =
      (uri.scheme == 'wss' && uri.port == 443) ||
      (uri.scheme == 'ws' && uri.port == kDefaultGamePort);
  final hostPort = defaultPort ? uri.host : '${uri.host}:${uri.port}';
  return uri.scheme == 'wss' ? 'wss://$hostPort' : hostPort;
}
