import 'package:web/web.dart' as web;

const _key = 'spades.tabClientId';

String? tabScopedId(String Function() generate) {
  try {
    final storage = web.window.sessionStorage;
    final existing = storage.getItem(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = generate();
    storage.setItem(_key, id);
    return id;
  } catch (_) {
    return null;
  }
}
