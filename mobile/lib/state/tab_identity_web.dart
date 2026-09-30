import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const _storageKey = 'spades.tabClientId';
const _channelName = 'spades-tab-ids';

Future<String?>? _resolved;

/// The id lives in sessionStorage (per tab, kept across reloads). A
/// duplicated tab inherits a copy of it, so before using it we ask the
/// other open tabs whether it's already taken, and pick a new one if so.
Future<String?> tabScopedId(String Function() generate) =>
    _resolved ??= _resolve(generate);

Future<String?> _resolve(String Function() generate) async {
  try {
    final storage = web.window.sessionStorage;
    var id = storage.getItem(_storageKey) ?? generate();
    final channel = web.BroadcastChannel(_channelName);
    final taken = Completer<bool>();
    var mine = id;

    channel.onmessage = ((web.MessageEvent event) {
      final data = event.data.dartify();
      if (data is! String) return;
      if (data == 'ask:$mine') {
        channel.postMessage('have:$mine'.toJS);
      } else if (data == 'have:$id' && !taken.isCompleted) {
        taken.complete(true);
      }
    }).toJS;

    channel.postMessage('ask:$id'.toJS);
    final duplicate = await taken.future.timeout(
      const Duration(milliseconds: 250),
      onTimeout: () => false,
    );
    if (duplicate) id = generate();
    mine = id;
    storage.setItem(_storageKey, id);
    // The channel stays open for the life of the tab, answering for [id].
    return id;
  } catch (_) {
    return null;
  }
}
